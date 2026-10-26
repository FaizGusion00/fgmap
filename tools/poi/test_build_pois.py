import gzip
import json
import os
import tempfile
import unittest

import build_pois as b


class Categories(unittest.TestCase):
    def test_osm(self):
        self.assertEqual(b.osm_category({"amenity": "fuel"}), "fuel")
        self.assertEqual(b.osm_category({"amenity": "cafe"}), "food")
        self.assertEqual(b.osm_category({"amenity": "place_of_worship", "religion": "muslim"}), "mosque")
        self.assertIsNone(b.osm_category({"amenity": "place_of_worship", "religion": "buddhist"}))
        self.assertIsNone(b.osm_category({"amenity": "place_of_worship"}))
        self.assertIsNone(b.osm_category({"shop": "mall"}))

    def test_overture(self):
        self.assertEqual(b.overture_category("gas_station"), "fuel")
        self.assertEqual(b.overture_category("mosque"), "mosque")
        self.assertEqual(b.overture_category("malaysian_restaurant"), "food")
        self.assertEqual(b.overture_category("coffee_shop"), "food")
        self.assertIsNone(b.overture_category("bank"))
        self.assertIsNone(b.overture_category(None))

    def test_codes_unique(self):
        self.assertEqual(len(set(b.CATEGORIES.values())), len(b.CATEGORIES))


class Merge(unittest.TestCase):
    def test_overture_duplicate_of_osm_is_dropped(self):
        osm = [("fuel", 3.1579, 101.7116, "Petron")]
        ovt = [("fuel", 3.15795, 101.71165, "PETRON KLCC")]  # ~7 m
        res, stats = b.merge(osm, ovt)
        self.assertEqual(len(res), 1)
        self.assertEqual(stats["fuel"]["overture_dup"], 1)

    def test_overture_far_away_is_added(self):
        res, stats = b.merge([("fuel", 3.1579, 101.7116, "A")], [("fuel", 3.1679, 101.7116, "B")])
        self.assertEqual(len(res), 2)
        self.assertEqual(stats["fuel"]["overture_added"], 1)

    def test_different_category_same_place_not_duplicate(self):
        res, _ = b.merge([("fuel", 3.1579, 101.7116, "A")], [("food", 3.1579, 101.7116, "Kedai")])
        self.assertEqual(len(res), 2)

    def test_same_name_within_30m_in_one_source_is_one(self):
        res, _ = b.merge([("food", 3.1579, 101.7116, "Nasi Lemak"), ("food", 3.15792, 101.71162, "nasi lemak")], [])
        self.assertEqual(len(res), 1)

    def test_same_place_different_names_in_osm_kept(self):
        res, _ = b.merge([("food", 3.1579, 101.7116, "Kedai A"), ("food", 3.15792, 101.71162, "Kedai B")], [])
        self.assertEqual(len(res), 2, "dua kedai bersebelahan ialah dua tempat")

    def test_food_without_name_is_not_kept(self):
        self.assertFalse(b.keep("food", ""))
        self.assertTrue(b.keep("mosque", ""))

    def test_singapore_excluded(self):
        self.assertTrue(b.in_singapore(1.3521, 103.8198))
        self.assertFalse(b.in_singapore(1.4927, 103.7414), "Johor Bahru bukan Singapura")


class Write(unittest.TestCase):
    def test_roundtrip_and_manifest_patch(self):
        with tempfile.TemporaryDirectory() as d:
            json.dump({"schema": 1, "version": "20261026"}, open(os.path.join(d, "manifest.json"), "w"))
            res = [("mosque", 3.2, 101.7, "Masjid Ä"), ("fuel", 3.1, 101.6, "")]
            meta = b.write(res, d, "20261026")
            self.assertEqual(meta["count"], 2)
            self.assertEqual(meta["counts"]["mosque"], 1)
            lines = [json.loads(l) for l in gzip.open(os.path.join(d, meta["file"]), "rt", encoding="utf-8")]
            self.assertEqual(lines[0], [0, 3.1, 101.6, ""], "disusun mengikut kategori: fuel=0 dahulu")
            self.assertEqual(lines[1], [2, 3.2, 101.7, "Masjid Ä"])
            m = json.load(open(os.path.join(d, "manifest.json")))
            self.assertEqual(m["poi"]["sha256"], meta["sha256"])
            self.assertEqual(m["version"], "20261026")


if __name__ == "__main__":
    unittest.main()
