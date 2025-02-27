import pathlib
import os

if __name__ == "__main__":
    code = pathlib.Path("build/package").read_text()
    template = pathlib.Path("taminomara-amm-ammcore/_templates/bootstrap/bootstrap.lua").read_text()
    result = template.replace("[[{ modules }]]", code)
    os.mkdir("build/docs")
    pathlib.Path("build/docs/bootstrap.lua").write_text(result)
    pathlib.Path("build/docs/.nojekyll").touch()
