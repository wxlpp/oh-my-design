"""公开 API 摘要必须保留并发修饰后的符号。"""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("digest", Path(__file__).with_name("design-digest.py"))
digest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(digest)


class IsolationModifiersTests(unittest.TestCase):
    def test_public_types_accept_both_modifier_orders(self):
        with tempfile.TemporaryDirectory() as root:
            source = Path(root) / "Sources/Example/Shapes.swift"
            source.parent.mkdir(parents=True)
            source.write_text("public nonisolated struct First: Shape {}\nnonisolated public struct Second: Shape {}\nprivate struct Hidden: Shape {}\n")
            names = [row[0] for file in digest.target_surface(root, "Example") for row in file[1]]
            self.assertEqual(names, ["First", "Second"])

    def test_public_color_isolation_preserves_visibility(self):
        with tempfile.TemporaryDirectory() as root:
            source = Path(root) / "Sources/OhMyDesign/Colors/MaskColors.swift"
            source.parent.mkdir(parents=True)
            source.write_text("public extension Color {\n    nonisolated static var opaque: Color { .white }\n    static var plain: Color { .black }\n    private static var hidden: Color { .black }\n}\nprivate extension Color {\n    nonisolated static var secret: Color { .white }\n}\n")
            names = [row[0] for _, rows in digest.semantic_colors(root) for row in rows]
            self.assertEqual(names, ["opaque", "plain"])


if __name__ == "__main__":
    unittest.main()
