import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() => runApp(MaterialApp(
      home: GirisEkrani(),
      debugShowCheckedModeBanner: false,
    ));

// ############################################################
// 1. VERİTABANI YARDIMCISI (SQLite İşlemleri)
// ############################################################
class VeritabaniYardimcisi {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    String yol = join(await getDatabasesPath(), "sehir_rehberi_2026.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // Kullanıcılar tablosu (İster 1)
      await db.execute(
          "CREATE TABLE kullanicilar (id INTEGER PRIMARY KEY AUTOINCREMENT, kadi TEXT, sifre TEXT)");
      // Yerler tablosu (İster 2)
      await db.execute(
          "CREATE TABLE yerler (id INTEGER PRIMARY KEY AUTOINCREMENT, mekan TEXT, tarih TEXT, lat REAL, lng REAL)");
      
      // Varsayılan kullanıcıyı ekle
      await db.insert("kullanicilar", {"kadi": "admin", "sifre": "1234"});
    });
  }

  Future<bool> girisKontrol(String kadi, String sifre) async {
    var dbClient = await db;
    var sonuc = await dbClient.query("kullanicilar",
        where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return sonuc.isNotEmpty;
  }
}

// ############################################################
// 2. GİRİŞ EKRANI (Kimlik Doğrulama)
// ############################################################
class GirisEkrani extends StatefulWidget {
  @override
  _GirisEkraniState createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final tKullanici = TextEditingController();
  final tSifre = TextEditingController();
  final vty = VeritabaniYardimcisi();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Şehir Rehberi Giriş")),
      body: Padding(
        padding: EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: tKullanici, decoration: InputDecoration(labelText: "Kullanıcı Adı (admin)")),
            TextField(controller: tSifre, decoration: InputDecoration(labelText: "Şifre (1234)"), obscureText: true),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                if (await vty.girisKontrol(tKullanici.text, tSifre.text)) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa()));
                } else {
                  tKullanici.clear();
                  tSifre.clear();
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
// 3. ANA SAYFA (Ziyaret Geçmişi ve Listeleme)
// ############################################################
class AnaSayfa extends StatefulWidget {
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final vty = VeritabaniYardimcisi();

  Future<List<Map<String, dynamic>>> yerleriGetir() async {
    var dbClient = await vty.db;
    // İster 3: Tarih sırasına göre (eskiden yeniye)
    return await dbClient.query("yerler", orderBy: "tarih ASC");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ziyaret Geçmişim")),
      drawer: YanMenu(), // İster 4: Yan Menü
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: yerleriGetir(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          var liste = snapshot.data!;
          return ListView.builder(
            itemCount: liste.length,
            itemBuilder: (context, index) {
              var yer = liste[index];
              return Card(
                elevation: 3,
                child: ListTile(
                  leading: Icon(Icons.map, color: Colors.blue),
                  title: Text(yer['mekan']),
                  subtitle: Text("Tarih: ${yer['tarih']}"),
                  // İster 3: Koordinatlar virgülden sonra 2 basamak
                  trailing: Text("${yer['lat'].toStringAsFixed(2)}, ${yer['lng'].toStringAsFixed(2)}"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ############################################################
// 4. EKLEME EKRANI (Harita ve Yer Kaydı)
// ############################################################
class EklemeEkrani extends StatefulWidget {
  @override
  _EklemeEkraniState createState() => _EklemeEkraniState();
}

class _EklemeEkraniState extends State<EklemeEkrani> {
  final tMekan = TextEditingController();
  final vty = VeritabaniYardimcisi();
  String secilenTarih = "Tarih Seçiniz";
  LatLng? secilenKonum;
  Set<Marker> isaretleyiciler = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Yer Kaydet")),
      drawer: YanMenu(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // İster 2: Ekranın üst yarısında harita
            Container(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(39.92, 32.85), zoom: 12),
                onTap: (konum) {
                  setState(() {
                    secilenKonum = konum;
                    isaretleyiciler = {Marker(markerId: MarkerId("yer"), position: konum)};
                  });
                },
                markers: isaretleyiciler,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(controller: tMekan, decoration: InputDecoration(labelText: "Mekan Adı")),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? dt = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (dt != null) setState(() => secilenTarih = DateFormat('yyyy-MM-dd').format(dt));
                    },
                    child: Text(secilenTarih),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (secilenKonum != null && tMekan.text.isNotEmpty) {
                        var dbClient = await vty.db;
                        await dbClient.insert("yerler", {
                          "mekan": tMekan.text,
                          "tarih": secilenTarih,
                          "lat": secilenKonum!.latitude,
                          "lng": secilenKonum!.longitude
                        });
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa()));
                      }
                    },
                    child: Text("KAYDET"),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 5. YAN MENÜ (Drawer)
// ############################################################
class YanMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(child: Center(child: Text("ŞEHİR REHBERİ 2026", style: TextStyle(fontSize: 20)))),
          ListTile(
            leading: Icon(Icons.list),
            title: Text("Ziyaretlerimi Listele"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa())),
          ),
          ListTile(
            leading: Icon(Icons.add_location_alt),
            title: Text("Yeni Yer Ekle"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EklemeEkrani())),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Güvenli Çıkış"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GirisEkrani())),
          ),
        ],
      ),
    );
  }
}
