import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() => runApp(MaterialApp(home: GirisEkrani(), debugShowCheckedModeBanner: false));

// ############################################################
// 1. VERİTABANI YARDIMCISI
// ############################################################
class DbHelper {
  static Database? _db;
  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  initDb() async {
    String yol = join(await getDatabasesPath(), "etkinlik_final.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // Tablo: Başlık, Tarih ve Kişi Sayısı kolonları var
      await db.execute("CREATE TABLE etkinlikler(id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, tarih TEXT, kisiSayisi INTEGER)");
      // Giriş için kullanıcı tablosu
      await db.execute("CREATE TABLE kullanicilar(id INTEGER PRIMARY KEY AUTOINCREMENT, kadi TEXT, sifre TEXT)");
      await db.insert("kullanicilar", {"kadi": "admin", "sifre": "1234"});
    });
  }

  Future<bool> girisYap(String kadi, String sifre) async {
    var res = await (await db)!.query("kullanicilar", where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return res.isNotEmpty;
  }

  Future<int> ekle(Map<String, dynamic> veri) async => (await db)!.insert("etkinlikler", veri);
  Future<List<Map<String, dynamic>>> listele() async => (await db)!.query("etkinlikler");
  
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
  final tKadi = TextEditingController();
  final tSifre = TextEditingController();
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Giriş Yap")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: tKadi, decoration: InputDecoration(labelText: "Kullanıcı Adı")),
            TextField(controller: tSifre, decoration: InputDecoration(labelText: "Şifre"), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
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
// 3. ANA SAYFA (LİSTELEME VE SİLME)
// ############################################################
class AnaSayfa extends StatefulWidget {
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final dbH = DbHelper();
  List<int> silinecekler = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Etkinlik Planlayıcı"), backgroundColor: Colors.red[900]),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbH.listele(),
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
                        title: Text(et["baslik"]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tarih: ${et["tarih"]} - Kişi: ${et["kisiSayisi"]}"),
                            // ÖDEV ŞARTI: Kullanıcının hareket ettiremediği slider
                            AbsorbPointer(child: Slider(value: 0.5, onChanged: (v) {})),
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                  onPressed: () async {
                    await dbH.secilileriSil(silinecekler);
                    setState(() { silinecekler.clear(); });
                  },
                  child: Text("Seçilenleri Sil", style: TextStyle(color: Colors.white)),
                ),
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
// 4. YENİ ETKİNLİK EKLEME EKRANI
// ############################################################
class EklemeEkrani extends StatefulWidget {
  @override
  _EklemeEkraniState createState() => _EklemeEkraniState();
}

class _EklemeEkraniState extends State<EklemeEkrani> {
  double kisiSayisi = 100;
  final tBaslik = TextEditingController();
  String secilenTarih = "Tarih Seçilmedi";
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Etkinlik")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Kişi Sayısı: ${kisiSayisi.toInt()}"),
            // Kullanıcının hareket ettirebildiği Slider
            Slider(value: kisiSayisi, min: 0, max: 1000, onChanged: (v) => setState(() => kisiSayisi = v)),
            TextField(controller: tBaslik, decoration: InputDecoration(labelText: "Etkinlik Adı")),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () async {
                DateTime? dt = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (dt != null) setState(() => secilenTarih = dt.toString().split(' ')[0]);
              },
              child: Text(secilenTarih),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              onPressed: () async {
                await dbH.ekle({"baslik": tBaslik.text, "tarih": secilenTarih, "kisiSayisi": kisiSayisi.toInt()});
                Navigator.pop(context);
              },
              child: Text("KAYDET"),
            )
          ],
        ),
      ),
    );
  }
}
