import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(MaterialApp(home: GirisEkrani(), debugShowCheckedModeBanner: false));

// ############################################################
// 1. VERİTABANI YARDIMCISI (Konum Verileri İçin)
// ############################################################
class DbHelper {
  static Database? _db;
  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  initDb() async {
    String yol = join(await getDatabasesPath(), "gezi_rehberi.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // Enlem (lat) ve Boylam (lng) bilgilerini double olarak saklıyoruz
      await db.execute("CREATE TABLE geziler(id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, tarih TEXT, lat REAL, lng REAL)");
      await db.execute("CREATE TABLE kullanicilar(id INTEGER PRIMARY KEY AUTOINCREMENT, kadi TEXT, sifre TEXT)");
      await db.insert("kullanicilar", {"kadi": "admin", "sifre": "1234"});
    });
  }

  Future<bool> girisYap(String kadi, String sifre) async {
    var res = await (await db)!.query("kullanicilar", where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return res.isNotEmpty;
  }

  Future<int> geziEkle(Map<String, dynamic> veri) async => (await db)!.insert("geziler", veri);
  Future<List<Map<String, dynamic>>> gezileriListele() async => (await db)!.query("geziler");
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
      appBar: AppBar(title: Text("Gezi Notlarım Giriş")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: tKadi, decoration: InputDecoration(labelText: "Kullanıcı Adı")),
            TextField(controller: tSifre, decoration: InputDecoration(labelText: "Şifre"), obscureText: true),
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
// 3. ANA SAYFA (LİSTELEME)
// ############################################################
class AnaSayfa extends StatelessWidget {
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gezdiğim Yerler")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbH.gezileriListele(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var gezi = snapshot.data![index];
              return ListTile(
                leading: Icon(Icons.map, color: Colors.green),
                title: Text(gezi["baslik"]),
                subtitle: Text("Tarih: ${gezi["tarih"]}"),
                trailing: Text("Konum: ${gezi["lat"].toStringAsFixed(2)}, ${gezi["lng"].toStringAsFixed(2)}"),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HaritaEklemeEkrani())),
        child: Icon(Icons.add_location_alt),
      ),
    );
  }
}

// ############################################################
// 4. HARİTA ÜZERİNDEN KONUM VE TARİH SEÇME EKRANI
// ############################################################
class HaritaEklemeEkrani extends StatefulWidget {
  @override
  _HaritaEklemeEkraniState createState() => _HaritaEklemeEkraniState();
}

class _HaritaEklemeEkraniState extends State<HaritaEklemeEkrani> {
  final tBaslik = TextEditingController();
  String secilenTarih = "Tarih Seçilmedi";
  LatLng secilenKonum = LatLng(39.9334, 32.8597); // Başlangıç: Ankara
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Yeni Yer Kaydet")),
      body: Column(
        children: [
          // Harita Alanı
          Container(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: secilenKonum, zoom: 10),
              onTap: (LatLng konum) {
                setState(() => secilenKonum = konum); // Haritaya tıklandığında konumu günceller
              },
              markers: {
                Marker(markerId: MarkerId("secilen"), position: secilenKonum) // Seçilen yere işaret koyar
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(controller: tBaslik, decoration: InputDecoration(labelText: "Gezi Notu / Mekan Adı")),
                ListTile(
                  title: Text(secilenTarih),
                  trailing: Icon(Icons.calendar_month),
                  onTap: () async {
                    DateTime? dt = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (dt != null) setState(() => secilenTarih = dt.toString().split(' ')[0]);
                  },
                ),
                Text("Seçilen Koordinat: ${secilenKonum.latitude.toStringAsFixed(4)}, ${secilenKonum.longitude.toStringAsFixed(4)}"),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await dbH.geziEkle({
                      "baslik": tBaslik.text,
                      "tarih": secilenTarih,
                      "lat": secilenKonum.latitude,
                      "lng": secilenKonum.longitude
                    });
                    Navigator.pop(context); // Ana sayfaya döner
                  },
                  child: Text("KONUMU VE NOTU KAYDET"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
