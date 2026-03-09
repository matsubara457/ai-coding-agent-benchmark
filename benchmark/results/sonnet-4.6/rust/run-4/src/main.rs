use actix_web::{web, App, HttpServer, HttpResponse, Scope};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

type Db = Arc<Mutex<Connection>>;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Todo {
    pub id: i64,
    pub title: String,
    pub completed: bool,
    pub created_at: String,
}

#[derive(Deserialize)]
pub struct CreateBody { pub title: String }

#[derive(Deserialize)]
pub struct UpdateBody {
    pub title: Option<String>,
    pub completed: Option<bool>,
}

fn fetch_todo(conn: &Connection, id: i64) -> Option<Todo> {
    conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id=?1",
        params![id],
        |r| Ok(Todo {
            id: r.get(0)?,
            title: r.get(1)?,
            completed: r.get::<_, i64>(2)? != 0,
            created_at: r.get(3)?,
        })
    ).ok()
}

async fn todos_list(db: web::Data<Db>) -> HttpResponse {
    let conn = db.lock().unwrap();
    let mut st = conn.prepare("SELECT id, title, completed, created_at FROM todos ORDER BY id").unwrap();
    let list: Vec<Todo> = st.query_map([], |r| Ok(Todo {
        id: r.get(0)?,
        title: r.get(1)?,
        completed: r.get::<_, i64>(2)? != 0,
        created_at: r.get(3)?,
    })).unwrap().filter_map(Result::ok).collect();
    HttpResponse::Ok().json(list)
}

async fn todos_create(db: web::Data<Db>, body: web::Json<CreateBody>) -> HttpResponse {
    let conn = db.lock().unwrap();
    conn.execute("INSERT INTO todos (title) VALUES (?1)", params![body.title]).unwrap();
    let todo = fetch_todo(&conn, conn.last_insert_rowid()).unwrap();
    HttpResponse::Created().json(todo)
}

async fn todos_update(db: web::Data<Db>, path: web::Path<i64>, body: web::Json<UpdateBody>) -> HttpResponse {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    match fetch_todo(&conn, id) {
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"})),
        Some(existing) => {
            let title = body.title.as_deref().unwrap_or(&existing.title).to_string();
            let completed = body.completed.unwrap_or(existing.completed);
            conn.execute("UPDATE todos SET title=?1, completed=?2 WHERE id=?3",
                params![title, completed as i64, id]).unwrap();
            HttpResponse::Ok().json(fetch_todo(&conn, id).unwrap())
        }
    }
}

async fn todos_delete(db: web::Data<Db>, path: web::Path<i64>) -> HttpResponse {
    let id = path.into_inner();
    let conn = db.lock().unwrap();
    if fetch_todo(&conn, id).is_none() {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"}));
    }
    conn.execute("DELETE FROM todos WHERE id=?1", params![id]).unwrap();
    HttpResponse::Ok().json(serde_json::json!({"message": "deleted"}))
}

fn todo_scope() -> Scope {
    web::scope("/todos")
        .route("", web::get().to(todos_list))
        .route("", web::post().to(todos_create))
        .route("/{id}", web::put().to(todos_update))
        .route("/{id}", web::delete().to(todos_delete))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").unwrap();
    conn.execute_batch("CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )").unwrap();
    let db: Db = Arc::new(Mutex::new(conn));
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(db.clone()))
            .service(todo_scope())
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
