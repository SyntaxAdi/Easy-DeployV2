#!/usr/bin/env python3
import sys
import json
from datetime import datetime

def ensure_pymongo():
    try:
        import pymongo
        return pymongo
    except ImportError:
        import subprocess
        try:
            subprocess.check_call([
                sys.executable, "-m", "pip", "install", "pymongo[srv]", "--quiet", "--break-system-packages"
            ])
            import pymongo
            return pymongo
        except Exception:
            try:
                subprocess.check_call([
                    sys.executable, "-m", "pip", "install", "pymongo[srv]", "--quiet"
                ])
                import pymongo
                return pymongo
            except Exception as e:
                sys.stderr.write(f"Error: pymongo is required for MongoDB operations on this system. Failed to auto-install: {e}\n")
                sys.exit(1)

def get_client(mongo_url):
    pymongo = ensure_pymongo()
    return pymongo.MongoClient(mongo_url, serverSelectionTimeoutMS=10000)

class MongoEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, datetime):
            return o.isoformat()
        try:
            from bson import ObjectId
            if isinstance(o, ObjectId):
                return str(o)
        except ImportError:
            pass
        return super().default(o)

def cmd_fetch_token(mongo_url):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    doc = db.secrets.find_one({"_id": "github_token"})
    if doc and "value" in doc:
        print(doc["value"])

def cmd_save_token(mongo_url, token):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.secrets.update_one(
        {"_id": "github_token"},
        {"$set": {"value": token}},
        upsert=True
    )

def cmd_save_repo(mongo_url, repo_name, repo_url, target_path):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.update_one(
        {"repo_name": repo_name},
        {"$set": {
            "repo_name": repo_name,
            "repo_url": repo_url,
            "target_path": target_path,
            "updated_at": datetime.utcnow()
        }},
        upsert=True
    )

def cmd_update_repo_commands(mongo_url, repo_name, venv_cmd, install_cmd, extra_install_cmd, apt_cmd):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.update_one(
        {"repo_name": repo_name},
        {"$set": {
            "venv_cmd": venv_cmd,
            "install_cmd": install_cmd,
            "extra_install_cmd": extra_install_cmd,
            "apt_cmd": apt_cmd,
            "updated_at": datetime.utcnow()
        }}
    )

def cmd_update_repo_env_file(mongo_url, repo_name, env_file, env_content):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.update_one(
        {"repo_name": repo_name},
        {"$set": {
            "env_file": env_file,
            "env_content": env_content,
            "updated_at": datetime.utcnow()
        }}
    )

def cmd_update_repo_screen_details(mongo_url, repo_name, screen_name, start_cmd):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.update_one(
        {"repo_name": repo_name},
        {"$set": {
            "screen_name": screen_name,
            "start_cmd": start_cmd,
            "updated_at": datetime.utcnow()
        }}
    )

def cmd_update_repo_field(mongo_url, repo_name, field_name, field_val):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.update_one(
        {"repo_name": repo_name},
        {"$set": {
            field_name: field_val,
            "updated_at": datetime.utcnow()
        }}
    )

def cmd_fetch_repos(mongo_url):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    docs = db.repos.find()
    for doc in docs:
        repo_name = doc.get("repo_name")
        repo_url = doc.get("repo_url")
        if repo_name and repo_url:
            print(f"{repo_name} | {repo_url}")

def cmd_fetch_repo_details(mongo_url, repo_name):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    doc = db.repos.find_one({"repo_name": repo_name})
    if doc:
        print(json.dumps(doc, cls=MongoEncoder))

def cmd_delete_repo(mongo_url, repo_name):
    client = get_client(mongo_url)
    db = client.get_database("deploy")
    db.repos.delete_one({"repo_name": repo_name})

def main():
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: mongo_helper.py <command> <mongo_url> [args...]\n")
        sys.exit(1)

    cmd = sys.argv[1]
    mongo_url = sys.argv[2]

    try:
        if cmd == "fetch_token":
            cmd_fetch_token(mongo_url)
        elif cmd == "save_token":
            token = sys.argv[3] if len(sys.argv) > 3 else ""
            cmd_save_token(mongo_url, token)
        elif cmd == "save_repo":
            repo_name = sys.argv[3]
            repo_url = sys.argv[4]
            target_path = sys.argv[5]
            cmd_save_repo(mongo_url, repo_name, repo_url, target_path)
        elif cmd == "update_repo_commands":
            repo_name = sys.argv[3]
            venv_cmd = sys.argv[4] if len(sys.argv) > 4 else ""
            install_cmd = sys.argv[5] if len(sys.argv) > 5 else ""
            extra_install_cmd = sys.argv[6] if len(sys.argv) > 6 else ""
            apt_cmd = sys.argv[7] if len(sys.argv) > 7 else ""
            cmd_update_repo_commands(mongo_url, repo_name, venv_cmd, install_cmd, extra_install_cmd, apt_cmd)
        elif cmd == "update_repo_env_file":
            repo_name = sys.argv[3]
            env_file = sys.argv[4] if len(sys.argv) > 4 else ""
            # If env_content passed via stdin or argv
            if len(sys.argv) > 5:
                env_content = sys.argv[5]
            else:
                env_content = sys.stdin.read()
            cmd_update_repo_env_file(mongo_url, repo_name, env_file, env_content)
        elif cmd == "update_repo_screen_details":
            repo_name = sys.argv[3]
            screen_name = sys.argv[4] if len(sys.argv) > 4 else ""
            start_cmd = sys.argv[5] if len(sys.argv) > 5 else ""
            cmd_update_repo_screen_details(mongo_url, repo_name, screen_name, start_cmd)
        elif cmd == "update_repo_field":
            repo_name = sys.argv[3]
            field_name = sys.argv[4]
            if len(sys.argv) > 5:
                field_val = sys.argv[5]
            else:
                field_val = sys.stdin.read()
            cmd_update_repo_field(mongo_url, repo_name, field_name, field_val)
        elif cmd == "fetch_repos":
            cmd_fetch_repos(mongo_url)
        elif cmd == "fetch_repo_details":
            repo_name = sys.argv[3]
            cmd_fetch_repo_details(mongo_url, repo_name)
        elif cmd == "delete_repo":
            repo_name = sys.argv[3]
            cmd_delete_repo(mongo_url, repo_name)
        else:
            sys.stderr.write(f"Unknown command: {cmd}\n")
            sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"MongoDB Helper Error: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
