use actix_web::{web, App, HttpServer, HttpResponse, middleware};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

#[derive(Debug, Serialize, Deserialize)]
struct Todo {
    id: i64,
    title: String,
    completed: bool,
    created_at: String,
}

#[derive(Debug, Deserialize)]
struct CreateTodoRequest {
    title: String,
}

#[derive(Debug, Deserialize)]
struct UpdateTodoRequest {
    title: Option<String>,
    completed: Option<bool>,
}

struct AppState {
    db: Mutex<Connection>,
}

fn init_db(conn: &Connection) {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed BOOLEAN NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        )",
        [],
    )
    .expect("Failed to create table");
}

async fn get_todos(data: web::Data<AppState>) -> HttpResponse {
    let conn = data.db.lock().unwrap();
    let mut stmt = conn
        .prepare("SELECT id, title, completed, created_at FROM todos")
        .unwrap();
    let todos: Vec<Todo> = stmt
        .query_map([], |row| {
            Ok(Todo {
                id: row.get(0)?,
                title: row.get(1)?,
                completed: row.get(2)?,
                created_at: row.get(3)?,
            })
        })
        .unwrap()
        .filter_map(|r| r.ok())
        .collect();
    HttpResponse::Ok().json(todos)
}

async fn create_todo(
    data: web::Data<AppState>,
    body: web::Json<CreateTodoRequest>,
) -> HttpResponse {
    let conn = data.db.lock().unwrap();
    let created_at = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
    conn.execute(
        "INSERT INTO todos (title, completed, created_at) VALUES (?1, ?2, ?3)",
        rusqlite::params![body.title, false, created_at],
    )
    .unwrap();
    let id = conn.last_insert_rowid();
    let todo = Todo {
        id,
        title: body.title.clone(),
        completed: false,
        created_at,
    };
    HttpResponse::Created().json(todo)
}

async fn update_todo(
    data: web::Data<AppState>,
    path: web::Path<i64>,
    body: web::Json<UpdateTodoRequest>,
) -> HttpResponse {
    let id = path.into_inner();
    let conn = data.db.lock().unwrap();

    // Check if todo exists
    let existing: Option<Todo> = conn
        .query_row(
            "SELECT id, title, completed, created_at FROM todos WHERE id = ?1",
            rusqlite::params![id],
            |row| {
                Ok(Todo {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    completed: row.get(2)?,
                    created_at: row.get(3)?,
                })
            },
        )
        .ok();

    let existing = match existing {
        Some(t) => t,
        None => {
            return HttpResponse::NotFound().json(serde_json::json!({"error": "not found"}));
        }
    };

    let title = body.title.clone().unwrap_or(existing.title);
    let completed = body.completed.unwrap_or(existing.completed);

    conn.execute(
        "UPDATE todos SET title = ?1, completed = ?2 WHERE id = ?3",
        rusqlite::params![title, completed, id],
    )
    .unwrap();

    let todo = Todo {
        id,
        title,
        completed,
        created_at: existing.created_at,
    };
    HttpResponse::Ok().json(todo)
}

async fn delete_todo(
    data: web::Data<AppState>,
    path: web::Path<i64>,
) -> HttpResponse {
    let id = path.into_inner();
    let conn = data.db.lock().unwrap();
    let rows_affected = conn
        .execute("DELETE FROM todos WHERE id = ?1", rusqlite::params![id])
        .unwrap();
    if rows_affected == 0 {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "not found"}));
    }
    HttpResponse::Ok().json(serde_json::json!({"message": "deleted"}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("todos.db").expect("Failed to open database");
    init_db(&conn);

    let data = web::Data::new(AppState {
        db: Mutex::new(conn),
    });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/todos", web::get().to(get_todos))
            .route("/todos", web::post().to(create_todo))
            .route("/todos/{id}", web::put().to(update_todo))
            .route("/todos/{id}", web::delete().to(delete_todo))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
