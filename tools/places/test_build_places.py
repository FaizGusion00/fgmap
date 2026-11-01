#!/usr/bin/env python3
"""Ujian unit ringan untuk peluasan liputan dan lapisan extra (tanpa PBF)."""
import json
import os
import tempfile
import unittest

import build_places as bp


class PoiCategoryTest(unittest.TestCase):
    def test_named_clothes_shop(self):
        self.assertEqual(bp.poi_category({"shop": "clothes", "name": "Uniqlo"}), ("shop", 18))

    def test_named_generic_shop(self):
        self.assertEqual(bp.poi_category({"shop": "yes", "name": "Kedai Runcit Ali"}), ("shop", 14))

    def test_unnamed_shop_skipped(self):
        self.assertIsNone(bp.poi_category({"shop": "yes"}))

    def test_leisure_fitness(self):
        self.assertEqual(bp.poi_category({"leisure": "fitness_centre", "name": "Fitness First"}), ("tourism", 35))

    def test_named_office(self):
        kind, rank = bp.poi_category({"office": "company", "name": "FG HQ"})
        self.assertEqual(kind, "other")
        self.assertEqual(rank, 28)

    def test_residential_landuse(self):
        self.assertEqual(
            bp.poi_category({"landuse": "residential", "name": "Taman Melawati"}),
            ("settlement", 42),
        )


class ExtraLayerTest(unittest.TestCase):
    def test_load_geojson(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "curated.geojson")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(
                    {
                        "type": "FeatureCollection",
                        "features": [
                            {
                                "type": "Feature",
                                "geometry": {"type": "Point", "coordinates": [101.7, 3.14]},
                                "properties": {"name": "Paan Spot", "kind": "food", "rank": 50},
                            }
                        ],
                    },
                    f,
                )
            rows = bp.load_extra_places(d)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], "Paan Spot")
            self.assertEqual(rows[0][2], "food")
            self.assertAlmostEqual(rows[0][3], 3.14)
            self.assertAlmostEqual(rows[0][4], 101.7)

    def test_missing_dir(self):
        self.assertEqual(bp.load_extra_places("/no/such/dir"), [])


if __name__ == "__main__":
    unittest.main()
