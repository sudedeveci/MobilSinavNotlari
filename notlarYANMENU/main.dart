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
    String yol = join(await getDatabasesPath(), "final_v3.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      await db.execute("CREATE TABLE kullanicilar(id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT, soyad TEXT, kurum TEXT, kadi TEXT, sifre TEXT)");
      await db.execute("CREATE TABLE notlar(id INTEGER PRIMARY KEY AUTOINCREMENT, tarih TEXT, icerik TEXT)");
    });
  }

  Future<int> kayitOl(Map<String, dynamic> veri) async => (await db)!.insert("kullanicilar", veri);
  
  Future<bool> girisKontrol(String kadi, String sifre) async {
    var res = await (await db)!.query("kullanicilar", where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return res.isNotEmpty;
  }

  Future<int> notEkle(String tarih, String icerik) async => (await db)!.insert("notlar", {"tarih": tarih, "icerik": icerik});

  Future<List<Map<String, dynamic>>> notlariListele() async => (await db)!.query("notlar", orderBy: "tarih ASC");
}

// ############################################################
// 2. ORTAK MENÜ BİLEŞENİ (Drawer)
// Bu menüyü hem Kaydet hem Listele ekranına ekleyerek geçişi sağlıyoruz.
// ############################################################
class YanMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Center(child: Text("UYGULAMA MENÜSÜ", style: TextStyle(color: Colors.white, fontSize: 20))),
          ),
          ListTile(
            leading: Icon(Icons.add_box),
            title: Text("Not Kaydet Ekranı"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => KaydetEkrani())),
          ),
          ListTile(
            leading: Icon(Icons.list),
            title: Text("Notları Listele Ekranı"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ListeEkrani())),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text("Çıkış Yap"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GirisEkrani())),
          ),
        ],
      ),
    );
  }
}

// ############################################################
// 3. KAYIT OL EKRANI (1. EKRAN)
// ############################################################
class KayitEkrani extends StatelessWidget {
  final tAd = TextEditingController(); final tSoyad = TextEditingController();
  final tKurum = TextEditingController(); final tKadi = TextEditingController();
  final tSifre1 = TextEditingController(); final tSifre2 = TextEditingController();
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Kayıt Ol")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(controller: tAd, decoration: InputDecoration(labelText: "İsim")),
            TextField(controller: tSoyad, decoration: InputDecoration(labelText: "Soyisim")),
            TextField(controller: tKurum, decoration: InputDecoration(labelText: "Kurum")),
            TextField(controller: tKadi, decoration: InputDecoration(labelText: "Kullanıcı Adı")),
            TextField(controller: tSifre1, decoration: InputDecoration(labelText: "Parola"), obscureText: true),
            TextField(controller: tSifre2, decoration: InputDecoration(labelText: "Parola Tekrar"), obscureText: true),
            ElevatedButton(
              onPressed: () async {
                if (tSifre1.text == tSifre2.text) {
                  await dbH.kayitOl({"ad": tAd.text, "soyad": tSoyad.text, "kurum": tKurum.text, "kadi": tKadi.text, "sifre": tSifre1.text});
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Parola hatalı")));
                }
              },
              child: Text("Kayıt Ol"),
            )
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 4. GİRİŞ EKRANI (2. EKRAN)
// ############################################################
class GirisEkrani extends StatelessWidget {
  final tKadi = TextEditingController(); final tSifre = TextEditingController();
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Giriş")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: tKadi, decoration: InputDecoration(labelText: "Kullanıcı Adı")),
            TextField(controller: tSifre, decoration: InputDecoration(labelText: "Parola"), obscureText: true),
            ElevatedButton(
              onPressed: () async {
                if (await dbH.girisKontrol(tKadi.text, tSifre.text)) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => KaydetEkrani()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tekrar deneyin")));
                }
              },
              child: Text("Giriş Yap"),
            ),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KayitEkrani())), child: Text("Hesap Oluştur"))
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 5. KAYDET EKRANI (3. EKRAN)
// ############################################################
class KaydetEkrani extends StatefulWidget {
  @override
  _KaydetEkraniState createState() => _KaydetEkraniState();
}

class _KaydetEkraniState extends State<KaydetEkrani> {
  final tNot = TextEditingController();
  String secilenTarih = "Tarih Seçilmedi";
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hatırlatma Kaydet")),
      drawer: YanMenu(), // MENÜ BURADA
      body: Column(
        children: [
          ListTile(
            title: Text(secilenTarih),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              DateTime? tarih = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (tarih != null) setState(() => secilenTarih = "${tarih.year}-${tarih.month}-${tarih.day}");
            },
          ),
          TextField(controller: tNot, decoration: InputDecoration(labelText: "Notunuz")),
          ElevatedButton(
            onPressed: () async {
              await dbH.notEkle(secilenTarih, tNot.text);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Not Kaydedildi")));
            },
            child: Text("KAYDET"),
          )
        ],
      ),
    );
  }
}

// ############################################################
// 6. LİSTELEME EKRANI (4. EKRAN)
// ############################################################
class ListeEkrani extends StatelessWidget {
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Not Listesi")),
      drawer: YanMenu(), // MENÜ BURADA DA VAR
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbH.notlariListele(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var veri = snapshot.data![index];
              return ListTile(
                leading: Text(veri["tarih"], style: TextStyle(fontWeight: FontWeight.bold)),
                title: Text(veri["icerik"], textAlign: TextAlign.right),
              );
            },
          );
        },
      ),
    );
  }
}
