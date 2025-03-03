import pathlib
import json

if __name__ == "__main__":
    data = {}
    template_path = pathlib.Path("server_template")
    for path, dirnames, filenames in template_path.walk():
        for filename in filenames:
            filepath = path / filename
            data[str(filepath.relative_to(template_path).as_posix())] = filepath.read_text()
    pathlib.Path("taminomara-amm-ammcore/_templates/server.json").write_text(json.dumps(data))
