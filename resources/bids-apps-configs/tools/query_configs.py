import os
import json
import yaml
from urllib.request import urlopen

# Load manifest.json from the repository
def load_manifest(repo_url):
    if repo_url.startswith("http"):
        with urlopen(f"{repo_url}/manifest.json") as response:
            return json.load(response)
    else:
        with open(os.path.join(repo_url, "manifest.json"), "r") as f:
            return json.load(f)

# Load a specific app configuration
def load_app_config(repo_url, app_name):
    manifest = load_manifest(repo_url)
    app_entry = next((app for app in manifest["apps"] if app["name"] == app_name), None)
    if not app_entry:
        raise ValueError(f"App {app_name} not found in manifest.")
    app_path = app_entry["path"]
    if repo_url.startswith("http"):
        with urlopen(f"{repo_url}/{app_path}") as response:
            return yaml.safe_load(response)
    else:
        with open(os.path.join(repo_url, app_path), "r") as f:
            return yaml.safe_load(f)

# Example usage
if __name__ == "__main__":
    repo_url = "https://github.com/your-org/bids-app-configs"
    app_name = "app1"
    config = load_app_config(repo_url, app_name)
    print(config)

