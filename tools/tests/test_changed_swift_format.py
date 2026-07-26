import sys
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lint_changed_swift_format as formatter


class ChangedSwiftFormatTests(unittest.TestCase):
    def test_selects_only_owned_swift_files(self) -> None:
        paths = [
            Path("Stronix-App/Sources/App/App.swift"),
            Path("Stronix-App/Tests/AppTests.swift"),
            Path("Stronix-App/Resources/Generated.swift"),
            Path("Vendor/Dependency.swift"),
            Path("Stronix-App/Sources/App/readme.txt"),
        ]

        selected = [path for path in paths if formatter.is_owned_swift_path(path)]

        self.assertEqual(
            selected,
            [
                Path("Stronix-App/Sources/App/App.swift"),
                Path("Stronix-App/Tests/AppTests.swift"),
            ],
        )

    @patch("lint_changed_swift_format.is_tracked", return_value=True)
    @patch("lint_changed_swift_format.Path.is_file", return_value=True)
    @patch("lint_changed_swift_format.changed_paths")
    def test_excludes_deleted_and_non_owned_files(
        self, changed_paths, is_file, is_tracked
    ) -> None:
        changed_paths.return_value = [
            Path("Stronix-App/Sources/App/New.swift"),
            Path("Pods/Dependency.swift"),
            Path("Stronix-App/Tests/Deleted.swift"),
        ]
        is_file.side_effect = [True, False]

        selected = formatter.changed_owned_swift_paths("base")

        self.assertEqual(selected, [Path("Stronix-App/Sources/App/New.swift")])
        is_tracked.assert_called_once_with(Path("Stronix-App/Sources/App/New.swift"))

    @patch("lint_changed_swift_format.subprocess.run")
    def test_lint_uses_read_only_lenient_invocation(self, run) -> None:
        run.return_value = SimpleNamespace(returncode=0)
        paths = [Path("Stronix-App/Sources/App/App.swift")]

        exit_code = formatter.lint(paths, "/tmp/swiftformat")

        self.assertEqual(exit_code, 0)
        self.assertEqual(
            run.call_args.args[0],
            [
                "/tmp/swiftformat",
                "--lint",
                "--lenient",
                "--reporter",
                "github-actions-log",
                "--config",
                ".swiftformat",
                "Stronix-App/Sources/App/App.swift",
            ],
        )

    @patch("lint_changed_swift_format.subprocess.run")
    def test_lint_preserves_non_style_failures(self, run) -> None:
        run.return_value = SimpleNamespace(returncode=2)

        self.assertEqual(
            formatter.lint([Path("Stronix-App/Sources/App/App.swift")], "swiftformat"),
            2,
        )

    @patch("lint_changed_swift_format.subprocess.run")
    def test_rejects_unpinned_formatter_version(self, run) -> None:
        run.return_value = SimpleNamespace(stdout="0.59.0\n")

        with self.assertRaisesRegex(RuntimeError, "Expected SwiftFormat 0.58.5"):
            formatter.verify_formatter_version("swiftformat")

    @patch("lint_changed_swift_format.lint")
    @patch("lint_changed_swift_format.verify_formatter_version")
    @patch("lint_changed_swift_format.changed_owned_swift_paths", return_value=[])
    @patch("lint_changed_swift_format.parse_args")
    def test_no_changed_files_skips_formatter(
        self, parse_args, changed_owned_swift_paths, verify_formatter_version, lint
    ) -> None:
        parse_args.return_value = SimpleNamespace(base="base", formatter="swiftformat")

        self.assertEqual(formatter.main(), 0)

        verify_formatter_version.assert_not_called()
        lint.assert_not_called()


if __name__ == "__main__":
    unittest.main()
