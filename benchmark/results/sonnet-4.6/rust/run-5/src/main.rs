use actix_web::{web, App, HttpServer, HttpResponse};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

struct Db(Mutex<Connection>);

#[derive(Serialize)] struct Todo { id: i64, title: String, completed: bool, created_at: String }
#[derive(Deserialize)] struct Cin { title: String }
#[derive(Deserialize)] struct Upd { title: Option<String>, completed: Option<bool> }

fn get_one(c: &Connection, id: i64) -> Option<Todo> {
    c.query_row("SELECT id,title,completed,created_at FROM todos WHERE id=?1", params![id],
        |r| Ok(Todo { id: r.get(0)?, title: r.get(1)?, completed: r.get::<_,i64>(2)?!=0, created_at: r.get(3)? })
    ).ok()
}

async fn list(d: web::Data<Db>) -> HttpResponse {
    let c = d.0.lock().unwrap();
    let mut s = c.prepare("SELECT id,title,completed,created_at FROM todos").unwrap();
    let v: Vec<Todo> = s.query_map([], |r| Ok(Todo {
        id: r.get(0)?, title: r.get(1)?, completed: r.get::<_,i64>(2)?!=0, created_at: r.get(3)?
    })).unwrap().filter_map(Result::ok).collect();
    HttpResponse::Ok().json(v)
}

async fn create(d: web::Data<Db>, b: web::Json<Cin>) -> HttpResponse {
    let c = d.0.lock().unwrap();
    c.execute("INSERT INTO todos (title) VALUES (?1)", params![b.title]).unwrap();
    HttpResponse::Created().json(get_one(&c, c.last_insert_rowid()).unwrap())
}

async fn update(d: web::Data<Db>, p: web::Path<i64>, b: web::Json<Upd>) -> HttpResponse {
    let id = p.into_inner();
    let c = d.0.lock().unwrap();
    match get_one(&c, id) {
        None => HttpResponse::NotFound().json(serde_json::json!({"error":"Not found"})),
        Some(e) => {
            let t = b.title.clone().unwrap_or(e.title);
            let cp = b.completed.unwrap_or(e.completed);
            c.execute("UPDATE todos SET title=?1,completed=?2 WHERE id=?3", params![t,cp as i64,id]).unwrap();
            HttpResponse::Ok().json(get_one(&c, id).unwrap())
        }
    }
}

async fn del(d: web::Data<Db>, p: web::Path<i64>) -> HttpResponse {
    let id = p.into_inner();
    let c = d.0.lock().unwrap();
    if get_one(&c, id).is_none() { return HttpResponse::NotFound().json(serde_json::json!({"error":"Not found"})); }
    c.execute("DELETE FROM todos WHERE id=?1", params![id]).unwrap();
    HttpResponse::Ok().json(serde_json::json!({"message":"deleted"}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").unwrap();
    conn.execute_batch("CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, completed INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')))").unwrap();
    let db = web::Data::new(Db(Mutex::new(conn)));
    HttpServer::new(move || App::new().app_data(db.clone())
        .route("/todos", web::get().to(list))
        .route("/todos", web::post().to(create))
        .route("/todos/{id}", web::put().to(update))
        .route("/todos/{id}", web::delete().to(del))
    ).bind("0.0.0.0:8080")?.run().await
}
