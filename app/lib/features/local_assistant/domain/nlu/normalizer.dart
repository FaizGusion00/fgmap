/// Penyeragaman bahasa SMS/Manglish/rojak sebelum padanan arahan (tanpa model).
///
/// Hanya menukar kata yang jelas bermaksud perkara lain dalam konteks arahan ("nk" -> "nak", "cmne" -> "macam mana").
/// Nama tempat tidak disentuh melainkan sama persis dengan entri kamus; entri yang berisiko (satu huruf) hanya
/// ditukar pada kedudukan arahan.
library;

/// Kata -> gantian (boleh beberapa token). Kunci huruf kecil tanpa tanda baca.
const slangDictionary = <String, String>{
  // kata kerja / hala
  'nk': 'nak',
  'xnak': 'tak nak',
  'xmo': 'tak mahu',
  'xmau': 'tak mahu',
  'takmo': 'tak mahu',
  'takmau': 'tak mahu',
  'xboleh': 'tak boleh',
  'gi': 'pergi',
  'pegi': 'pergi',
  'pgi': 'pergi',
  'bawak': 'bawa',
  'bwa': 'bawa',
  'bwk': 'bawa',
  'hntr': 'hantar',
  'cri': 'cari',
  'carik': 'cari',
  'rute': 'route',
  'rout': 'route',
  'tlg': 'tolong',
  'tolg': 'tolong',
  'tulung': 'tolong',
  // tanya
  'cmne': 'macam mana',
  'cmna': 'macam mana',
  'camne': 'macam mana',
  'cemane': 'macam mana',
  'cemana': 'macam mana',
  'macamane': 'macam mana',
  'mcm': 'macam',
  'mane': 'mana',
  'kemane': 'ke mana',
  'kemana': 'ke mana',
  'dmn': 'di mana',
  'dmna': 'di mana',
  'dimana': 'di mana',
  'dimane': 'di mana',
  'brape': 'berapa',
  'berape': 'berapa',
  'brp': 'berapa',
  'bape': 'berapa',
  'lg': 'lagi',
  'lagik': 'lagi',
  'lgi': 'lagi',
  // kata fungsi
  'kt': 'kat',
  'dkt': 'dekat',
  'dgn': 'dengan',
  'dengn': 'dengan',
  'utk': 'untuk',
  'untk': 'untuk',
  'yg': 'yang',
  'sy': 'saya',
  'sya': 'saya',
  'ak': 'aku',
  'jgn': 'jangan',
  'skrg': 'sekarang',
  'skang': 'sekarang',
  'sekarg': 'sekarang',
  'jln': 'jalan',
  'tmpt': 'tempat',
  'lbh': 'lebih',
  'blk': 'balik',
  'balek': 'balik',
  'balk': 'balik',
  // tempat tersimpan
  'umah': 'rumah',
  'rumh': 'rumah',
  'rmh': 'rumah',
  'ofis': 'pejabat',
  'opis': 'pejabat',
  'pejabt': 'pejabat',
  'pjbt': 'pejabat',
  // vendor / ejaan biasa
  'masjed': 'masjid',
  'mesjid': 'masjid',
  'msjid': 'masjid',
  'petrul': 'petrol',
  'pertol': 'petrol',
  'tndas': 'tandas',
  'weder': 'weather',
  'wether': 'weather',
  'weathr': 'weather',
  'nearst': 'nearest',
  'neerest': 'nearest',
  'navigat': 'navigate',
  'navigete': 'navigate',
};

/// Kata satu huruf yang hanya bermakna slang pada kedudukan arahan.
const _followersOfX = {
  'nak',
  'mahu',
  'mau',
  'mo',
  'boleh',
  'payah',
  'perlu',
  'lalu',
  'ada',
  'tau',
  'tahu',
  'jadi',
  'nk',
};

const _leadersOfG = {
  'nk',
  'nak',
  'jom',
  'mahu',
  'hendak',
  'saya',
  'aku',
  'sy',
  'kita',
  'ak',
  'kami',
  'tolong',
  'tlg',
};

/// Tukar slang kepada bentuk piawai. Input mesti sudah melalui `normalizeCommand` (huruf kecil, tanpa tanda baca).
String canonicalizeSlang(String normalized) {
  final tokens = normalized.split(' ').where((e) => e.isNotEmpty).toList();
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final w = tokens[i];
    final next = i + 1 < tokens.length ? tokens[i + 1] : null;
    final prev = i > 0 ? tokens[i - 1] : null;
    if (w == 'x') {
      if (next != null && _followersOfX.contains(next)) {
        out.add('tak');
        continue;
      }
      out.add(w);
      continue;
    }
    if (w == 'g') {
      if (i <= 2 &&
          next != null &&
          (prev == null || _leadersOfG.contains(prev))) {
        out.add('pergi');
        continue;
      }
      out.add(w);
      continue;
    }
    final rep = slangDictionary[w];
    out.add(rep ?? w);
  }
  return out.join(' ');
}
