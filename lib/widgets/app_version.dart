import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersion extends StatelessWidget {
  const AppVersion({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final defaultStyle = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withOpacity(0.6),
      fontWeight: FontWeight.w500,
    );

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final version = snapshot.data!.version;
        final buildNumber = snapshot.data!.buildNumber;
        final versionText = 'v$version${buildNumber != '1' ? '+$buildNumber' : ''}';

        return Text(
          versionText,
          style: style ?? defaultStyle,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

