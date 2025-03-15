import pathlib

if __name__ == "__main__":
    code = pathlib.Path("build/package").read_text()
    template = pathlib.Path("taminomara-amm-ammcore/_templates/bootstrap/bootstrap.lua").read_text()
    result = template.replace("[[{ modules }]]", code)
    pathlib.Path("docs/_build/html/").mkdir(exist_ok=True)
    pathlib.Path("docs/_build/html/bootstrap.lua").write_text(result)
