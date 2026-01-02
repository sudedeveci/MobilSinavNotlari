import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // SQLite veritabanı işlemleri için
import 'package:path/path.dart';       // Dosya yolu işlemleri için

// Uygulama Giriş Ekranı ile başlar
void main() => runApp(MaterialApp(home: GirisEkrani(), debugShowCheckedModeBanner: false));

// ############################################################
// 1. VERİTABANI YARDIMCISI (Kullanıcı ve Etkinlik Tabloları)
// ############################################################
class DbHelper {
  static Database? _db;
  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  // Veritabanı ve tabloların oluşturulması
  initDb() async {
    String yol = join(await getDatabasesPath(), "etkinlik_v3.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // Etkinlikler Tablosu: Başlık, tarih, kişi sayısı ve resim yolu tutar
      await db.execute("CREATE TABLE etkinlikler(id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, tarih TEXT, kisiSayisi INTEGER, resim TEXT)");
      // Kullanıcı Tablosu: Giriş yapmak için kullanıcı adı ve şifre tutar
      await db.execute("CREATE TABLE kullanicilar(id INTEGER PRIMARY KEY AUTOINCREMENT, kadi TEXT, sifre TEXT)");
      // Sınavda test edebilmek için varsayılan bir kullanıcı ekliyoruz
      await db.insert("kullanicilar", {"kadi": "admin", "sifre": "1234"});
    });
  }

  // Kullanıcı adı ve şifrenin veritabanında kontrol edilmesi
  Future<bool> girisYap(String kadi, String sifre) async {
    var dbClient = await db;
    var res = await dbClient!.query("kullanicilar", where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return res.isNotEmpty; // Liste doluysa giriş başarılıdır
  }

  // Yeni etkinlik ekleme
  Future<int> ekle(Map<String, dynamic> veri) async => (await db)!.insert("etkinlikler", veri);
  
  // Tüm etkinlikleri listeleme
  Future<List<Map<String, dynamic>>> listele() async => (await db)!.query("etkinlikler");
  
  // Seçilen ID'leri toplu olarak silme
  Future<void> secilileriSil(List<int> idler) async {
    var dbClient = await db;
    for (var id in idler) {
      await dbClient!.delete("etkinlikler", where: "id = ?", whereArgs: [id]);
    }
  }
}

// ############################################################
// 2. GİRİŞ EKRANI
// ############################################################
class GirisEkrani extends StatelessWidget {
  final tKadi = TextEditingController(); // Kullanıcı adı kontrolcüsü
  final tSifre = TextEditingController(); // Şifre kontrolcüsü
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Etkinlik Planlayıcı Giriş"), backgroundColor: Colors.blueGrey),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: tKadi, decoration: InputDecoration(labelText: "Kullanıcı Adı (admin)")),
            TextField(controller: tSifre, decoration: InputDecoration(labelText: "Şifre (1234)"), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Bilgiler doğruysa Ana Sayfaya geç ve bu ekranı kapat
                if (await dbH.girisYap(tKadi.text, tSifre.text)) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hatalı Giriş!")));
                }
              },
              child: Text("GİRİŞ YAP"),
            )
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 3. ANA SAYFA (Etkinlik Listesi ve İşlemler)
// ############################################################
class AnaSayfa extends StatefulWidget {
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final dbH = DbHelper();
  List<int> silinecekler = []; // Checkbox ile işaretlenenlerin listesi

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Etkinlik Planlayıcı"), backgroundColor: Colors.red[900]),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbH.listele(), // Veritabanından verileri çek
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          var liste = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: liste.length,
                  itemBuilder: (context, index) {
                    var et = liste[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue),
                        title: Text(et["baslik"]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${et["tarih"]} - KS: ${et["kisiSayisi"]}"),
                            // Ödev Şartı: Tıklanamayan/Hareket etmeyen Slider
                            AbsorbPointer(child: Slider(value: 0.3, onChanged: (v) {})),
                          ],
                        ),
                        trailing: Checkbox(
                          value: silinecekler.contains(et["id"]),
                          onChanged: (val) {
                            setState(() { val! ? silinecekler.add(et["id"]) : silinecekler.remove(et["id"]); });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await dbH.secilileriSil(silinecekler); // İşaretlenenleri sil
                  setState(() { silinecekler.clear(); });
                },
                child: Text("Seçilenleri Sil"),
              )
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EklemeEkrani())),
        child: Icon(Icons.add),
      ),
    );
  }
}

// ############################################################
// 4. EKLEME EKRANI (Yeni Veri Girişi)
// ############################################################
class EklemeEkrani extends StatefulWidget {
  @override
  _EklemeEkraniState createState() => _EklemeEkraniState();
}

class _EklemeEkraniState extends State<EklemeEkrani> {
  double kisiSayisi = 100; // Slider başlangıç değeri
  final tBaslik = TextEditingController();
  String secilenTarih = "Tarih Seçin";
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Etkinlik"), backgroundColor: Colors.grey),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Kişi Sayısı: ${kisiSayisi.toInt()}"),
            Slider(value: kisiSayisi, min: 0, max: 1000, onChanged: (v) => setState(() => kisiSayisi = v)),
            TextField(controller: tBaslik, decoration: InputDecoration(labelText: "Etkinlik Adı")),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                // Takvimi aç ve tarih seç
                DateTime? dt = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (dt != null) setState(() => secilenTarih = dt.toString().split(' ')[0]);
              },
              child: Text(secilenTarih),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Verileri kaydet ve geri dön
                await dbH.ekle({"baslik": tBaslik.text, "tarih": secilenTarih, "kisiSayisi": kisiSayisi.toInt(), "resim": ""});
                Navigator.pop(context);
              },
              child: Text("Kaydet ve Ana Sayfaya Dön"),
            )
          ],
        ),
      ),
    );
  }
}
