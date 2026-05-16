class BancoInfo {
  final String nombre;
  final String url;

  const BancoInfo({required this.nombre, required this.url});

  String get faviconUrl {
    if (url.isEmpty) return '';
    return 'https://www.google.com/s2/favicons?sz=64&domain=${Uri.parse(url).host}';
  }

  String get initials {
    final words = nombre.split(RegExp(r'[\s()]+'));
    final letters = words.where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

const List<BancoInfo> kBancos = [
  // Bancos argentinos
  BancoInfo(nombre: 'Banco de la Nación Argentina',      url: 'https://www.bna.com.ar'),
  BancoInfo(nombre: 'Banco Galicia',                      url: 'https://www.galicia.ar'),
  BancoInfo(nombre: 'Banco Santander Argentina',          url: 'https://www.santander.com.ar'),
  BancoInfo(nombre: 'Banco Macro',                        url: 'https://www.macro.com.ar'),
  BancoInfo(nombre: 'BBVA Argentina',                     url: 'https://www.bbva.com.ar'),
  BancoInfo(nombre: 'Banco de la Provincia de Buenos Aires', url: 'https://www.bapro.com.ar'),
  BancoInfo(nombre: 'Banco Credicoop',                    url: 'https://www.bancocredicoop.coop'),
  BancoInfo(nombre: 'ICBC Argentina',                     url: 'https://www.icbc.com.ar'),
  BancoInfo(nombre: 'Banco Patagonia',                    url: 'https://www.bancopatagonia.com.ar'),
  BancoInfo(nombre: 'Banco Ciudad de Buenos Aires',       url: 'https://www.bancociudad.com.ar'),
  BancoInfo(nombre: 'HSBC Bank Argentina',                url: 'https://www.hsbc.com.ar'),
  BancoInfo(nombre: 'Banco Supervielle',                  url: 'https://www.supervielle.com.ar'),
  BancoInfo(nombre: 'Banco Hipotecario',                  url: 'https://www.hipotecario.com.ar'),
  BancoInfo(nombre: 'Banco Comafi',                       url: 'https://www.comafi.com.ar'),
  BancoInfo(nombre: 'Banco del Sol',                      url: 'https://www.bancodelsol.com.ar'),
  BancoInfo(nombre: 'Bancor',                             url: 'https://www.bancor.com.ar'),
  BancoInfo(nombre: 'Nuevo Banco de Santa Fe',            url: 'https://www.nbsf.com.ar'),
  BancoInfo(nombre: 'Citibank N.A. Argentina',            url: 'https://www.citi.com'),
  BancoInfo(nombre: 'Banco Columbia',                     url: 'https://www.columbia.com.ar'),
  BancoInfo(nombre: 'Banco Piano',                        url: 'https://www.piano.com.ar'),
  BancoInfo(nombre: 'J.P. Morgan Chase Bank Argentina',   url: 'https://www.jpmorgan.com'),
  BancoInfo(nombre: 'BST',                                url: 'https://www.bst.com.ar'),
  BancoInfo(nombre: 'Banco de la Pampa',                  url: 'https://www.blp.com.ar'),
  BancoInfo(nombre: 'Banco de Corrientes',                url: 'https://www.bancocorrientes.com.ar'),
  BancoInfo(nombre: 'Banco Municipal de Rosario',         url: 'https://www.bmr.com.ar'),
  // Bancos internacionales
  BancoInfo(nombre: 'ICBC Global',                        url: 'https://www.icbc.com.cn'),
  BancoInfo(nombre: 'Agricultural Bank of China',         url: 'https://www.abchina.com'),
  BancoInfo(nombre: 'China Construction Bank',            url: 'https://www.ccb.com'),
  BancoInfo(nombre: 'Bank of China',                      url: 'https://www.bankofchina.com'),
  BancoInfo(nombre: 'JPMorgan Chase',                     url: 'https://www.jpmorganchase.com'),
  BancoInfo(nombre: 'Bank of America',                    url: 'https://www.bankofamerica.com'),
  BancoInfo(nombre: 'HSBC Holdings',                      url: 'https://www.hsbc.com'),
  BancoInfo(nombre: 'BNP Paribas',                        url: 'https://www.bnpparibas.com'),
  BancoInfo(nombre: 'Crédit Agricole',                    url: 'https://www.credit-agricole.com'),
  BancoInfo(nombre: 'MUFG',                               url: 'https://www.mufg.jp'),
  BancoInfo(nombre: 'Sumitomo Mitsui',                    url: 'https://www.smfg.co.jp'),
  BancoInfo(nombre: 'Citigroup',                          url: 'https://www.citigroup.com'),
  BancoInfo(nombre: 'Postal Savings Bank of China',       url: 'https://www.psbc.com'),
  BancoInfo(nombre: 'Mizuho',                             url: 'https://www.mizuho-fg.co.jp'),
  BancoInfo(nombre: 'Barclays',                           url: 'https://www.barclays.com'),
  BancoInfo(nombre: 'Santander Group',                    url: 'https://www.santander.com'),
  BancoInfo(nombre: 'UBS Group',                          url: 'https://www.ubs.com'),
  BancoInfo(nombre: 'Deutsche Bank',                      url: 'https://www.db.com'),
  BancoInfo(nombre: 'Goldman Sachs',                      url: 'https://www.goldmansachs.com'),
  BancoInfo(nombre: 'TD Bank',                            url: 'https://www.td.com'),
  BancoInfo(nombre: 'Royal Bank of Canada',               url: 'https://www.rbc.com'),
  BancoInfo(nombre: 'Wells Fargo',                        url: 'https://www.wellsfargo.com'),
  BancoInfo(nombre: 'Morgan Stanley',                     url: 'https://www.morganstanley.com'),
  BancoInfo(nombre: 'Intesa Sanpaolo',                    url: 'https://www.intesasanpaolo.com'),
  BancoInfo(nombre: 'Société Générale',                   url: 'https://www.societegenerale.com'),
  BancoInfo(nombre: 'Otro',                               url: ''),
];
