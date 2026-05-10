class L10n {
  final String code;
  const L10n._(this.code);

  static const en = L10n._('en');
  static const si = L10n._('si');
  static L10n fromCode(String? c) => c == 'si' ? si : en;
  bool get isSinhala => code == 'si';

  // Generic
  String get appName      => 'UNITY-MD';
  String get teamName     => '® UNITY TEAM';
  String get cancel       => isSinhala ? 'අවලංගු'        : 'Cancel';
  String get disconnect   => isSinhala ? 'විසන්ධි කරන්න' : 'Disconnect';
  String get language     => 'Language';

  // Splash
  String get starting     => isSinhala ? 'ආරම්භ වෙනවා...'        : 'Starting...';
  String get reconnecting => isSinhala ? 'නැවත සම්බන්ධ වෙනවා...' : 'Reconnecting...';

  // Setup
  String get setupTitle     => isSinhala ? 'සකසන්න'                   : 'Setup';
  String get whatsappNumber => isSinhala ? 'WhatsApp අංකය'            : 'WhatsApp Number';
  String get phoneHelper    => isSinhala
      ? 'රටේ කේතය select කර ඔබේ අංකය ඇතුළු කරන්න'
      : 'Select country code then enter your number';
  String get connectBtn     => isSinhala ? 'WhatsApp සම්බන්ධ කරන්න'  : 'Connect WhatsApp';
  String get invalidPhone   => isSinhala ? 'වලංගු අංකයක් ඇතුළු කරන්න' : 'Enter a valid number';
  String get serverError    => isSinhala ? 'සේවාදායකය ළඟා කළ නොහැක.'  : 'Server unreachable.';
  String get timeout        => isSinhala ? 'කාලය ඉකුත් විය.'          : 'Timeout. Try again.';
  String get selectCountry  => isSinhala ? 'රට තෝරන්න'                : 'Select Country';

  List<String> get setupSteps => isSinhala
      ? [
          '1️⃣  අංකය ඇතුළු කර "සම්බන්ධ කරන්න" tap කරන්න',
          '2️⃣  WhatsApp → Settings → Linked Devices',
          '3️⃣  Link a Device → ඉලක්කම් 8 කේතය ඇතුළු කරන්න',
          '4️⃣  Bot සක්‍රිය! 🚀',
        ]
      : [
          '1️⃣  Enter number & tap "Connect"',
          '2️⃣  WhatsApp → Settings → Linked Devices',
          '3️⃣  Link a Device → Enter the 8-digit code',
          '4️⃣  Bot is active! 🚀',
        ];

  // Pairing
  String get pairingCode => isSinhala ? 'යුගල කිරීමේ කේතය' : 'PAIRING CODE';
  String get copy        => isSinhala ? 'පිටපත් කරන්න'      : 'Copy';
  String get copied      => isSinhala ? 'පිටපත් විය!'        : 'Copied!';
  String get waitingScan => isSinhala ? 'Scan කිරීමට රැඳෙනවා...' : 'Waiting for scan...';

  List<(String, String)> get pairingSteps => isSinhala
      ? [
          ('1.', 'WhatsApp විවෘත කරන්න'),
          ('2.', 'Settings → Linked Devices'),
          ('3.', '"Link a Device" tap කරන්න'),
          ('4.', 'කේතය ඇතුළු කරන්න ✅'),
        ]
      : [
          ('1.', 'Open WhatsApp'),
          ('2.', 'Settings → Linked Devices'),
          ('3.', 'Tap "Link a Device"'),
          ('4.', 'Enter the code ✅'),
        ];

  // Home
  String get features   => isSinhala ? 'විශේෂාංග'   : 'FEATURES';
  String get uptime     => isSinhala ? 'ක්‍රියා කාලය' : 'Uptime';
  String get commands   => isSinhala ? 'විධාන'       : 'Commands';
  String get antiBan    => 'Anti-Ban';

  String get disconnectTitle => isSinhala ? 'විසන්ධි කරන්නද?' : 'Disconnect?';
  String get disconnectBody  => isSinhala ? 'Bot විසන්ධි වෙනවා.' : 'Bot will be disconnected.';

  String get menuTip => isSinhala
      ? 'WhatsApp හි .menu ටයිප් කර සියලු විධාන බලන්න.'
      : 'Type .menu in WhatsApp to see all commands.';

  // Contact / About menu
  String get contactUs   => isSinhala ? 'අප අමතන්න'  : 'Contact Us';
  String get owner       => isSinhala ? 'හිමිකරු'    : 'Owner';
  String get developer   => isSinhala ? 'සංවර්ධක'    : 'Developer';
  String get supporter   => isSinhala ? 'සහාය'       : 'Supporter';
  String get aboutApp    => isSinhala ? 'ගැන'         : 'About';
  String get version     => 'v1.0.0';
  String get builtWith   => isSinhala ? 'Flutter + WhatsApp API' : 'Flutter + WhatsApp API';
  String get closeBtn    => isSinhala ? 'වසන්න'       : 'Close';

  String statusLabel(String s) {
    switch (s) {
      case 'connected':    return isSinhala ? '● Bot සක්‍රිය'       : '● Bot Active';
      case 'pairing':      return isSinhala ? '○ යුගල කෙරෙමින්...' : '○ Pairing...';
      case 'connecting':   return isSinhala ? '○ සම්බන්ධ වෙනවා...' : '○ Connecting...';
      case 'disconnected': return isSinhala ? '○ නොබැඳි'           : '○ Offline';
      default:             return s;
    }
  }

  List<(String, String, String)> get featureCards => isSinhala
      ? [
          ('🤖', 'AI Mode',    'Gemini Pro මගින් බල ගැන්වේ'),
          ('📥', 'Downloader', 'YT, TikTok, FB සහ තවත්'),
          ('🎮', 'Games',      'විනෝදජනක කණ්ඩායම් ක්‍රීඩා'),
          ('⚙️', 'Settings',  '.settings හරහා Configure'),
        ]
      : [
          ('🤖', 'AI Mode',    'Gemini Pro powered'),
          ('📥', 'Downloader', 'YT, TikTok, FB & more'),
          ('🎮', 'Games',      'Fun group games'),
          ('⚙️', 'Settings',  'Configure via WhatsApp (.settings)'),
        ];
}
