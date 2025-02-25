import argparse
import os
import pathlib
import subprocess


def run(*args):
    script = pathlib.Path(__file__).parent / "loader.lua"
    args = ["lua", str(script), *args]

    for _ in range(5):
        res = subprocess.run(args)

        if res.returncode == 0:
            return
        elif res.returncode != 15:
            res.check_returncode()
        else:
            print("\x1b[2mDEBUG: Got a call to 'computer.reset', restarting\x1b[0m")
    else:
        raise subprocess.SubprocessError("Too many restarts, aborting.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--local", action="store_true",
                        help="do not download AMM from github, try to find a local version")
    parser.add_argument("--setup", action="store_true",
                        help="setup package dependencies")
    parser.add_argument("--test", action="store_true",
                        help="run the package test")
    parser.add_argument("--build", action="store_true",
                        help="run the package build")
    parser.add_argument("--nick",
                        help="run the package using this computer nick")
    parser.add_argument("--user",
                        help="run the package using this computer nick")
    parser.add_argument("--repo",
                        help="run the package using this computer nick")
    parser.add_argument("--tag",
                        help="run the package using this computer nick")
    config = parser.parse_args()

    args = []

    if config.local:
        args.append("--local")

    nick_args = []
    if config.user:
        nick_args.append(f"user={config.user}")
    if config.repo:
        nick_args.append(f"repo={config.repo}")
    if config.tag:
        nick_args.append(f"tag={config.tag}")

    if config.setup:
        run(*args, "ammcore/bin/installPackages", "#", *nick_args)

    if config.test:
        run(*args, "ammtest/bin/main", "#", *nick_args)

    if config.build:
        run(*args, "ammcore/bin/buildPackage", "#", *nick_args)

    if config.nick:
        run(*args, config.nick)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\x1b[31mERROR: {e}\x1b[0m")
        exit(1)
