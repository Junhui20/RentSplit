enum InternetProvider {
  unifi,
  maxis,
  celcom,
  digi,
  umobile,
  yes,
  redone,
  viewqwest,
  time,
  astro,
}

extension InternetProviderExtension on InternetProvider {
  String get displayName {
    switch (this) {
      case InternetProvider.unifi:
        return 'Unifi (TM)';
      case InternetProvider.maxis:
        return 'Maxis';
      case InternetProvider.celcom:
        return 'Celcom';
      case InternetProvider.digi:
        return 'Digi';
      case InternetProvider.umobile:
        return 'U Mobile';
      case InternetProvider.yes:
        return 'Yes';
      case InternetProvider.redone:
        return 'RedONE';
      case InternetProvider.viewqwest:
        return 'ViewQwest';
      case InternetProvider.time:
        return 'TIME';
      case InternetProvider.astro:
        return 'Astro';
    }
  }

  String get value => name;

  static InternetProvider fromValue(String value) {
    return InternetProvider.values.firstWhere(
      (provider) => provider.value == value,
      orElse: () => InternetProvider.unifi,
    );
  }

  String get description {
    switch (this) {
      case InternetProvider.unifi:
        return 'TM Unifi - Fiber broadband service';
      case InternetProvider.maxis:
        return 'Maxis - Mobile and fiber internet';
      case InternetProvider.celcom:
        return 'Celcom - Mobile and broadband services';
      case InternetProvider.digi:
        return 'Digi - Mobile and fiber internet';
      case InternetProvider.umobile:
        return 'U Mobile - Mobile internet services';
      case InternetProvider.yes:
        return 'Yes - 4G and fiber internet';
      case InternetProvider.redone:
        return 'RedONE - Fiber broadband service';
      case InternetProvider.viewqwest:
        return 'ViewQwest - Fiber internet service';
      case InternetProvider.time:
        return 'TIME - Fiber broadband service';
      case InternetProvider.astro:
        return 'Astro - Satellite and fiber internet';
    }
  }

  // Common speed packages for each provider
  List<String> get commonPackages {
    switch (this) {
      case InternetProvider.unifi:
        return ['30 Mbps', '100 Mbps', '300 Mbps', '500 Mbps', '800 Mbps'];
      case InternetProvider.maxis:
        return ['100 Mbps', '300 Mbps', '500 Mbps', '800 Mbps'];
      case InternetProvider.celcom:
        return ['100 Mbps', '300 Mbps', '500 Mbps'];
      case InternetProvider.digi:
        return ['100 Mbps', '300 Mbps', '500 Mbps', '1 Gbps'];
      case InternetProvider.umobile:
        return ['100 Mbps', '300 Mbps', '500 Mbps'];
      case InternetProvider.yes:
        return ['100 Mbps', '300 Mbps', '500 Mbps', '1 Gbps'];
      case InternetProvider.redone:
        return ['100 Mbps', '300 Mbps', '500 Mbps'];
      case InternetProvider.viewqwest:
        return ['100 Mbps', '300 Mbps', '500 Mbps', '1 Gbps'];
      case InternetProvider.time:
        return ['100 Mbps', '500 Mbps', '1 Gbps'];
      case InternetProvider.astro:
        return ['30 Mbps', '100 Mbps', '300 Mbps'];
    }
  }
}

class MalaysianInternetProviders {
  static List<InternetProvider> get allProviders => InternetProvider.values;
  
  static List<InternetProvider> get popularProviders => [
    InternetProvider.unifi,
    InternetProvider.maxis,
    InternetProvider.digi,
    InternetProvider.yes,
    InternetProvider.time,
  ];
  
  static InternetProvider? getProviderById(String id) {
    try {
      return InternetProviderExtension.fromValue(id);
    } catch (e) {
      return null;
    }
  }
}
