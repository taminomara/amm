# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import glob

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = "AMM"
copyright = "2025, Tamika Nomara"
author = "Tamika Nomara"

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = ["sphinx_lua_ls", "sphinx_design"]

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

primary_domain = "lua"
default_role = "lua:obj"

lua_ls_project_root = ".."
lua_ls_project_directories = [
    "taminomara-amm-ammcore",
    "taminomara-amm-ammtest",
    "taminomara-amm-ammgui",
]
lua_ls_default_options = {
    "members": "",
    "protected-members": "",
    "inherited-members": "New",
    "member-order": "bysource",
    "module-member-order": "groupwise",
}
lua_ls_apidoc_roots = {
    "ammcore": "ammcore/api",
    "ammtest": "ammtest/api",
    "ammgui": "ammgui/api",
}
lua_ls_apidoc_ignored_modules = [
    "taminomara-amm-*/_*",
    "taminomara-amm-*/bin",
]

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "furo"
html_theme_options = {
    "source_repository": "https://github.com/taminomara/amm",
    "source_branch": "main",
    "source_directory": "docs",
}
