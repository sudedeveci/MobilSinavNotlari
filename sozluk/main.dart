import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // Veritabanı paketini içe aktarır
import 'package:path/path.dart';       // Dosya yolları için gerekli

void main() => runApp(MaterialApp(home: AnaSayfa(), debugShowCheckedModeBanner: false));

// ############################################################
// 1. VERİTABANI YARDIMCISI (DB HELPER)
// ############################################################
class DbHelper {
  static Database? _db;

  // Veritabanı dosyasına erişimi kontrol eden fonksiyon
  Future<Database?> get db async {
    if (_db != null) return _db; // Zaten varsa onu döndür
    _db = await initDb();        // Yoksa yeni oluştur
    return _db;
  }

  // Veritabanını oluşturma ve Tablo tanımlama
  initDb() async {
    String yol = join(await getDatabasesPath(), "sozluk_db.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // Kelimeler tablosu: id, ingilizce ve turkce kolonları
      await db.execute("CREATE TABLE kelimeler(id INTEGER PRIMARY KEY AUTOINCREMENT, ing TEXT, tr TEXT)");
    });
  }

  // Veritabanına veri ekleme fonksiyonu
  Future<int> kelimeEkle(String ingilizce, String turkce) async {
    var dbClient = await db;
    return await dbClient!.insert("kelimeler", {"ing": ingilizce, "tr": turkce});
  }

  // Veritabanındaki tüm verileri listeleme fonksiyonu
  Future<List<Map<String, dynamic>>> kelimeleriGetir() async {
    var dbClient = await db;
    return await dbClient!.query("kelimeler");
  }
}

// ############################################################
// 2. ANA SAYFA (MENÜ)
// ############################################################
class AnaSayfa extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sözlük Uygulaması")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ekleme sayfasına gider
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EkleSayfasi())),
              child: Text("KELİME EKLE"),
            ),
            // Listeleme sayfasına gider
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListeSayfasi())),
              child: Text("LİSTELE"),
            ),
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 3. EKLEME SAYFASI
// ############################################################
class EkleSayfasi extends StatelessWidget {
  final tIng = TextEditingController(); // İngilizce kutusu için kontrolcü
  final tTr = TextEditingController();  // Türkçe kutusu için kontrolcü
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Kelime Ekle")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: tIng, decoration: InputDecoration(labelText: "İngilizce Kelime")),
            TextField(controller: tTr, decoration: InputDecoration(labelText: "Türkçe Karşılığı")),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Kaydet butonuna basınca veritabanına yazar
                await dbH.kelimeEkle(tIng.text, tTr.text);
                tIng.clear(); tTr.clear(); // Kutuları boşaltır
                // Ekranın altına mesaj çıkartır
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kaydedilmiştir")));
              },
              child: Text("KAYDET"),
            ),
            // Ana sayfaya geri döndürür
            ElevatedButton(onPressed: () => Navigator.pop(context), child: Text("ANA SAYFA")),
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 4. LİSTELEME SAYFASI (FutureBuilder ile)
// ############################################################
class ListeSayfasi extends StatelessWidget {
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Kayıtlı Kelimeler")),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: dbH.kelimeleriGetir(), // Veritabanından listeyi ister
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                
                var liste = snapshot.data!;
                return ListView.builder(
                  itemCount: liste.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(liste[index]["ing"]), // İngilizce başlık
                      subtitle: Text(liste[index]["tr"]), // Türkçe alt yazı
                    );
                  },
                );
              },
            ),
          ),
          // Listeleme bittikten sonra ana sayfaya dönme butonu
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text("ANA SAYFA")),
        ],
      ),
    );
  }
}
