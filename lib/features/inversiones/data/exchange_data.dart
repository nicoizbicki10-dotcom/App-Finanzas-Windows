class ExchangeInfo {
  final String nombre;
  final String url;

  const ExchangeInfo({required this.nombre, required this.url});

  String get faviconUrl => 'https://www.google.com/s2/favicons?sz=64&domain=${Uri.parse(url).host}';

  String get initials {
    final words = nombre.split(RegExp(r'[\s()]+'));
    final letters = words.where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

const List<ExchangeInfo> kExchanges = [
  ExchangeInfo(nombre: 'Binance',                       url: 'https://www.binance.com'),
  ExchangeInfo(nombre: 'Interactive Brokers (IBKR)',    url: 'https://www.interactivebrokers.com'),
  ExchangeInfo(nombre: 'Invertir Online (IOL)',         url: 'https://invertironline.com'),
  ExchangeInfo(nombre: 'Balanz Capital',                url: 'https://balanz.com'),
  ExchangeInfo(nombre: 'Coinbase',                      url: 'https://www.coinbase.com'),
  ExchangeInfo(nombre: 'Charles Schwab',                url: 'https://www.schwab.com'),
  ExchangeInfo(nombre: 'Cocos Capital',                 url: 'https://cocos.capital'),
  ExchangeInfo(nombre: 'eToro',                         url: 'https://www.etoro.com'),
  ExchangeInfo(nombre: 'Portfolio Personal (PPI)',      url: 'https://portfoliopersonal.com'),
  ExchangeInfo(nombre: 'Lemon Cash',                    url: 'https://www.lemon.me'),
  ExchangeInfo(nombre: 'Bybit',                         url: 'https://www.bybit.com'),
  ExchangeInfo(nombre: 'Fidelity Investments',          url: 'https://www.fidelity.com'),
  ExchangeInfo(nombre: 'Vanguard',                      url: 'https://www.vanguard.com'),
  ExchangeInfo(nombre: 'OKX',                           url: 'https://www.okx.com'),
  ExchangeInfo(nombre: 'Bull Market Brokers',           url: 'https://www.bullmarket.com.ar'),
  ExchangeInfo(nombre: 'Hapi',                          url: 'https://www.hapi.com.ar'),
  ExchangeInfo(nombre: 'Kraken',                        url: 'https://www.kraken.com'),
  ExchangeInfo(nombre: 'Bitget',                        url: 'https://www.bitget.com'),
  ExchangeInfo(nombre: 'XTB',                           url: 'https://www.xtb.com'),
  ExchangeInfo(nombre: 'Capital.com',                   url: 'https://capital.com'),
  ExchangeInfo(nombre: 'Allaria Ledesma',               url: 'https://www.allaria.com.ar'),
  ExchangeInfo(nombre: 'Buenbit',                       url: 'https://buenbit.com'),
  ExchangeInfo(nombre: 'Ripio',                         url: 'https://ripio.com'),
  ExchangeInfo(nombre: 'Robinhood',                     url: 'https://robinhood.com'),
  ExchangeInfo(nombre: 'Belo',                          url: 'https://belo.app'),
  ExchangeInfo(nombre: 'KuCoin',                        url: 'https://www.kucoin.com'),
  ExchangeInfo(nombre: 'DEGIRO',                        url: 'https://www.degiro.com'),
  ExchangeInfo(nombre: 'Crypto.com',                    url: 'https://crypto.com'),
  ExchangeInfo(nombre: 'Bitso',                         url: 'https://bitso.com'),
  ExchangeInfo(nombre: 'Saxo Bank',                     url: 'https://www.home.saxo'),
  ExchangeInfo(nombre: 'Trade Republic',                url: 'https://traderepublic.com'),
  ExchangeInfo(nombre: 'Fiwind',                        url: 'https://fiwind.io'),
  ExchangeInfo(nombre: 'Inviu',                         url: 'https://www.inviu.com.ar'),
  ExchangeInfo(nombre: 'IG Group',                      url: 'https://www.ig.com'),
  ExchangeInfo(nombre: 'Admiral Markets',               url: 'https://admiralmarkets.com'),
  ExchangeInfo(nombre: 'Pepperstone',                   url: 'https://pepperstone.com'),
  ExchangeInfo(nombre: 'Swissquote',                    url: 'https://www.swissquote.com'),
  ExchangeInfo(nombre: 'AvaTrade',                      url: 'https://www.avatrade.com'),
  ExchangeInfo(nombre: 'Rava Bursátil',                 url: 'https://www.rava.com'),
  ExchangeInfo(nombre: 'LetsBit',                       url: 'https://letsbit.io'),
  ExchangeInfo(nombre: 'MEXC',                          url: 'https://www.mexc.com'),
  ExchangeInfo(nombre: 'Plus500',                       url: 'https://www.plus500.com'),
  ExchangeInfo(nombre: 'Gemini',                        url: 'https://www.gemini.com'),
  ExchangeInfo(nombre: 'Trading 212',                   url: 'https://www.trading212.com'),
  ExchangeInfo(nombre: 'SBS Trading',                   url: 'https://www.sbstrading.com.ar'),
  ExchangeInfo(nombre: 'Eco Valores',                   url: 'https://www.ecovalores.com.ar'),
  ExchangeInfo(nombre: 'Gate.io',                       url: 'https://www.gate.io'),
  ExchangeInfo(nombre: 'OANDA',                         url: 'https://www.oanda.com'),
  ExchangeInfo(nombre: 'Tastytrade',                    url: 'https://tastytrade.com'),
  ExchangeInfo(nombre: 'E*TRADE',                       url: 'https://us.etrade.com'),
];
