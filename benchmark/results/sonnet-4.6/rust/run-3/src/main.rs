use actix_web::{web, App, HttpServer, HttpResponse};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

struct AppState {
    db: Mutex<Connection>,
}

#[derive(Serialize)]
struct Todo {
    id: i64,
    title: String,
    completed: bool,
    created_at: String,
}

#[derive(Deserialize)]
struct NewTodo { title: String }

#[derive(Deserialize)]
struct PatchTodo {
    title: Option<String>,
    completed: Option<bool>,
}

fn query_todo(conn: &Connection, id: i64) -> Option<Todo> {
    conn.query_row(
        "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
        params![id],
        |r| Ok(Todo {
            id: r.get(0)?,
            title: r.get(1)?,
            completed: r.get::<_, i64>(2)? != 0,
            created_at: r.get(3)?,
        })
    ).ok()
}

async fn index(state: web::Data<AppState>) -> HttpResponse {
    let conn = state.db.lock().unwrap();
    let mut stmt = conn.prepare("SELECT id, title, completed, created_at FROM todos").unwrap();
    let items: Vec<Todo> = stmt.query_map([], |r| Ok(Todo {
        id: r.get(0)?,
        title: r.get(1)?,
        completed: r.get::<_, i64>(2)? != 0,
        created_at: r.get(3)?,
    })).unwrap().filter_map(Result::ok).collect();
    HttpResponse::Ok().json(items)
}

async fn create(state: web::Data<AppState>, body: web::Json<NewTodo>) -> HttpResponse {
    let conn = state.db.lock().unwrap();
    conn.execute("INSERT INTO todos (title) VALUES (?1)", params![body.title]).unwrap();
    let id = conn.last_insert_rowid();
    let todo = query_todo(&conn, id).unwrap();
    HttpResponse::Created().json(todo)
}

async fn update(state: web::Data<AppState>, path: web::Path<i64>, body: web::Json<PatchTodo>) -> HttpResponse {
    let id = path.into_inner();
    let conn = state.db.lock().unwrap();
    match query_todo(&conn, id) {
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"})),
        Some(e) => {
            let t = body.title.clone().unwrap_or(e.title);
            let c = body.completed.unwrap_or(e.completed);
            conn.execute("UPDATE todos SET title=?1, completed=?2 WHERE id=?3", params![t, c as i64, id]).unwrap();
            HttpResponse::Ok().json(query_todo(&conn, id).unwrap())
        }
    }
}

async fn delete(state: web::Data<AppState>, path: web::Path<i64>) -> HttpResponse {
    let id = path.into_inner();
    let conn = state.db.lock().unwrap();
    if query_todo(&conn, id).is_none() {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "Not found"}));
    }
    conn.execute("DELETE FROM todos WHERE id=?1", params![id]).unwrap();
    HttpResponse::Ok().json(serde_json::json!({"message": "deleted"}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").unwrap();
    conn.execute_batch("CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
    )").unwrap();
    let data = web::Data::new(AppState { db: Mutex::new(conn) });
    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/todos", web::get().to(index))
            .route("/todos", web::post().to(create))
            .route("/todos/{id}", web::put().to(update))
            .route("/todos/{id}", web::delete().to(delete))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
