import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Uygulama Giriş Ekranı ile başlar
void main() => runApp(MaterialApp(home: GirisEkrani(), debugShowCheckedModeBanner: false));

// ############################################################
// 1. VERİTABANI YARDIMCISI (Kullanıcılar ve Notlar Tabloları)
// ############################################################
class DbHelper {
  static Database? _db;
  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  initDb() async {
    String yol = join(await getDatabasesPath(), "final_soru.db");
    return await openDatabase(yol, version: 1, onCreate: (db, version) async {
      // 1. Tablo: Kullanıcı Bilgileri
      await db.execute("CREATE TABLE kullanicilar(id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT, soyad TEXT, kurum TEXT, kadi TEXT, sifre TEXT)");
      // 2. Tablo: Tarihli Notlar
      await db.execute("CREATE TABLE notlar(id INTEGER PRIMARY KEY AUTOINCREMENT, tarih TEXT, icerik TEXT)");
    });
  }

  // --- Kullanıcı Kayıt Fonksiyonu ---
  Future<int> kayitOl(Map<String, dynamic> veri) async {
    var dbClient = await db;
    return await dbClient!.insert("kullanicilar", veri);
  }

  // --- Giriş Kontrol Fonksiyonu ---
  Future<bool> girisKontrol(String kadi, String sifre) async {
    var dbClient = await db;
    var sonuc = await dbClient!.query("kullanicilar", where: "kadi = ? AND sifre = ?", whereArgs: [kadi, sifre]);
    return sonuc.isNotEmpty; // Eşleşme varsa true döner
  }

  // --- Not Kaydetme ve Listeleme ---
  Future<int> notEkle(String tarih, String icerik) async {
    var dbClient = await db;
    return await dbClient!.insert("notlar", {"tarih": tarih, "icerik": icerik});
  }

  Future<List<Map<String, dynamic>>> notlariListele() async {
    var dbClient = await db;
    // SORU ŞARTI: Tarihsel sırayla listeleme (ASC: Eskiden yeniye)
    return await dbClient!.query("notlar", orderBy: "tarih ASC");
  }
}

// ############################################################
// 2. KAYIT OL EKRANI (Şifre Kontrolü Buradadır)
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
      body: SingleChildScrollView( // Klavye açılınca ekran taşmasın diye
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
                // SORU ŞARTI: Parola kontrolü
                if (tSifre1.text == tSifre2.text) {
                  await dbH.kayitOl({"ad": tAd.text, "soyad": tSoyad.text, "kurum": tKurum.text, "kadi": tKadi.text, "sifre": tSifre1.text});
                  Navigator.pop(context); // Kayıt başarılıysa geri dön
                } else {
                  // SORU ŞARTI: Uyarı mesajı
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
// 3. GİRİŞ EKRANI
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
                  // Başarılıysa Menüye git
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MenuEkrani()));
                } else {
                  // SORU ŞARTI: Başarısız uyarısı
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tekrar deneyin")));
                }
              },
              child: Text("Giriş Yap"),
            ),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KayitEkrani())), child: Text("Yeni Hesap Oluştur"))
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 4. MENÜ EKRANI (Ana Geçiş Ekranı)
// ############################################################
class MenuEkrani extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Menü")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KaydetEkrani())), child: Text("Not Kaydet")),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListeEkrani())), child: Text("Notları Listele")),
          ],
        ),
      ),
    );
  }
}

// ############################################################
// 5. NOT KAYDET EKRANI (Takvim Seçimi Dahil)
// ############################################################
class KaydetEkrani extends StatefulWidget {
  @override
  _KaydetEkraniState createState() => _KaydetEkraniState();
}

class _KaydetEkraniState extends State<KaydetEkrani> {
  final tNot = TextEditingController();
  String secilenTarih = "Tarih Seçilmedi"; // Seçilen tarihi tutar
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hatırlatma Kaydet")),
      body: Column(
        children: [
          // SORU ŞARTI: DatePicker (Tarih Seçici)
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
// 6. LİSTELEME EKRANI (Solda Tarih Sağda Not)
// ############################################################
class ListeEkrani extends StatelessWidget {
  final dbH = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Not Listesi")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbH.notlariListele(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var veri = snapshot.data![index];
              return ListTile(
                // SORU ŞARTI: Solda Tarih
                leading: Text(veri["tarih"], style: TextStyle(fontWeight: FontWeight.bold)),
                // SORU ŞARTI: Sağda Not (TextAlign.right ile sağa yasladık)
                title: Text(veri["icerik"], textAlign: TextAlign.right),
              );
            },
          );
        },
      ),
    );
  }
}
