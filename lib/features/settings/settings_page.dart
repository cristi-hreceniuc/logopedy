import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Setări',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            // Dark Mode Toggle
            _SettingsSection(
              title: 'Aspect',
              children: [
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, themeMode) {
                    final isDark = themeMode == ThemeMode.dark;
                    return _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: const Color(0xFF2D72D2),
                      title: 'Mod întunecat',
                      trailing: Switch(
                        value: isDark,
                        onChanged: (value) {
                          context.read<ThemeCubit>().set(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                        activeThumbColor: const Color(0xFFEA2233),
                        activeTrackColor: const Color(0xFFEA2233).withOpacity(0.5),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Legal & Information Section
            _SettingsSection(
              title: 'Informații și Legal',
              children: [
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF2D72D2),
                  title: 'Termeni și condiții',
                  onTap: () => _showTermsAndConditions(context),
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF2D72D2),
                  title: 'Despre aplicație',
                  onTap: () => _showAbout(context),
                ),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF2D72D2),
                  title: 'Întrebări frecvente (FAQ)',
                  onTap: () => _showFAQ(context),
                ),
                _SettingsTile(
                  icon: Icons.support_agent_outlined,
                  iconColor: const Color(0xFF2D72D2),
                  title: 'Ajutor',
                  onTap: () => _showHelp(context),
                ),
                _SettingsTile(
                  icon: Icons.cookie_outlined,
                  iconColor: const Color(0xFFEA2233),
                  title: 'Cookie-uri',
                  onTap: () => _showCookies(context),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: const Color(0xFFEA2233),
                  title: 'Declarație de confidențialitate',
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Termeni și condiții',
        content: _termsAndConditionsContent,
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Despre aplicație',
        content: _aboutContent,
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FAQBottomSheet(),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Ajutor',
        content: _helpContent,
      ),
    );
  }

  void _showCookies(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Politica Cookie-uri',
        content: _cookiesContent,
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(
        title: 'Declarație de confidențialitate',
        content: _privacyContent,
      ),
    );
  }

  static const String _termsAndConditionsContent = '''
TERMENI ȘI CONDIȚII DE UTILIZARE

1. ACCEPTAREA TERMENILOR
Prin accesarea și utilizarea aplicației Logopedy, acceptați acești termeni și condiții în totalitate. Dacă nu sunteți de acord cu oricare dintre acești termeni, vă rugăm să nu utilizați aplicația.

2. DESCRIEREA SERVICIULUI
Aplicația Logopedy oferă servicii de terapie logopedică prin intermediul unor exerciții interactive și conținut educațional adaptat pentru utilizatori.

3. CONTUL UTILIZATORULUI
Sunteți responsabil pentru menținerea confidențialității contului dvs. și pentru toate activitățile care au loc sub contul dvs.

4. UTILIZAREA APLICAȚIEI
Aplicația este destinată utilizării personale și educaționale. Nu puteți:
- Copia sau distribui conținutul aplicației
- Utiliza aplicația în scopuri comerciale fără autorizație
- Încerca să accesezi zone restricționate ale aplicației

5. PROPRETATEA INTELECTUALĂ
Toate drepturile de proprietate intelectuală asupra aplicației și conținutului acesteia aparțin Logopedy.

6. LIMITAREA RĂSPUNDERII
Aplicația este furnizată "așa cum este" fără garanții. Nu ne asumăm răspundere pentru eventualele daune rezultate din utilizarea aplicației.

7. MODIFICĂRI
Ne rezervăm dreptul de a modifica acești termeni în orice moment. Continuarea utilizării aplicației după modificări constituie acceptarea noilor termeni.
''';

  static const String _aboutContent = '''
DESPRE APLICAȚIA LOGOPEDY

Logopedy este o aplicație modernă și intuitivă concepută pentru a sprijini terapia logopedică prin intermediul tehnologiei.

CARACTERISTICI PRINCIPALE:
• Exerciții interactive pentru dezvoltarea vorbirii
• Module personalizate pentru fiecare utilizator
• Tracking al progresului
• Interfață prietenoasă și intuitivă

MISIUNEA NOASTRĂ:
Să oferim o soluție accesibilă și eficientă pentru terapia logopedică, facilitând procesul de învățare și dezvoltare a abilităților de comunicare.

VERSIUNEA APLICAȚIEI:
Versiunea curentă include funcționalități complete pentru gestionarea profilurilor, accesarea modulelor educaționale și urmărirea progresului.

PENTRU SUPPORT:
Pentru întrebări sau suport tehnic, vă rugăm să ne contactați prin intermediul secțiunii de ajutor.
''';

  static const String _helpContent = '''
AJUTOR ȘI SUPPORT

CUM PUTEȚI OBȚINE AJUTOR:

1. CENTRU DE AJUTOR
Explorează secțiunea de întrebări frecvente (FAQ) pentru răspunsuri la cele mai comune întrebări.

2. CONTACT SUPPORT
Dacă ai nevoie de asistență suplimentară, te rugăm să ne contactezi:
• Email: support@logopedy.ro
• Telefon: [Număr de telefon]

3. GĂSIȚI RĂSPUNSURI RAPIDE:
• Probleme de conectare: Verifică conexiunea la internet
• Probleme cu contul: Verifică credențialele de autentificare
• Probleme tehnice: Încearcă să repornești aplicația

4. FEEDBACK
Valorăm feedback-ul tău! Dacă ai sugestii sau întâmpini probleme, te rugăm să ne contactezi.

PROBLEME COMUNE:

• "Nu pot accesa modulele"
  Soluție: Asigură-te că ai un profil activ selectat.

• "Aplicația se blochează"
  Soluție: Încearcă să ștergi cache-ul aplicației sau să o reinstalezi.

• "Nu primesc notificări"
  Soluție: Verifică setările de notificări în telefon.
''';

  static const String _cookiesContent = '''
POLITICA COOKIE-URI

1. CE SUNT COOKIE-URILE
Cookie-urile sunt fișiere text mici stocate pe dispozitivul dvs. când accesați aplicația sau site-ul nostru web.

2. TIPURI DE COOKIE-URI UTILIZATE

Cookie-uri esențiale:
Acestea sunt necesare pentru funcționarea aplicației și nu pot fi dezactivate.

Cookie-uri de performanță:
Acestea ne ajută să înțelegem cum utilizați aplicația pentru a îmbunătăți performanța.

Cookie-uri de funcționalitate:
Acestea permit aplicației să își amintească preferințele dvs. (de ex., limba, tema).

3. GESTIONAREA COOKIE-URILOR
Puteți gestiona preferințele cookie-urilor prin setările dispozitivului dvs. sau browser-ului.

4. COOKIE-URI TERȚE
Unele servicii terțe folosite în aplicație pot folosi propriile cookie-uri. Acestea sunt supuse politicilor de confidențialitate ale respectivilor furnizori.

5. ACTUALIZĂRI
Ne rezervăm dreptul de a actualiza această politică. Modificările vor fi publicate în această secțiune.
''';

  static String get _privacyContent => '''
DECLARAȚIE DE CONFIDENȚIALITATE

1. PRELUCRAREA DATELOR
Prelucrăm datele personale în conformitate cu Regulamentul General privind Protecția Datelor (GDPR) și legislația română aplicabilă.

2. DATELE COLECTATE
Colectăm următoarele tipuri de date:
• Informații de identificare (nume, email)
• Date de profil (varstă, gen)
• Date de utilizare (progres, activități)
• Date tehnice (adresă IP, tip de dispozitiv)

3. UTILIZAREA DATELOR
Utilizăm datele pentru:
• Furnizarea serviciilor aplicației
• Îmbunătățirea experienței utilizatorului
• Analiza utilizării și performanței
• Comunicații importante despre serviciu

4. SECURITATEA DATELOR
Implementăm măsuri de securitate tehnice și organizaționale pentru a proteja datele dvs. personale împotriva accesului neautorizat, pierderii sau distrugerii.

5. PARTAJAREA DATELOR
Nu vindem datele dvs. personale. Putem partaja date doar în următoarele situații:
• Cu servicii terțe necesare pentru funcționarea aplicației
• Când este necesar conform legii
• Cu consimțământul dvs. explicit

6. DREPTURILE DVS.
Aveți dreptul la:
• Acces la datele dvs. personale
• Rectificarea datelor incorecte
• Ștergerea datelor (dreptul de a fi uitat)
• Restricționarea prelucrării
• Portabilitatea datelor
• Opoziție față de prelucrare

7. STOCAREA DATELOR
Păstrăm datele dvs. personale doar atât timp cât este necesar pentru scopurile menționate sau conform cerințelor legale.

8. CONTACT
Pentru întrebări despre confidențialitate, contactați-ne la: privacy@logopedy.ro

Ultima actualizare: ${DateTime.now().year}
''';
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? const Color(0xFF1B1B20)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null) ...[
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBottomSheet extends StatelessWidget {
  final String title;
  final String content;

  const _InfoBottomSheet({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark
                ? const Color(0xFF1B1B20)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: cs.onSurface,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: cs.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FAQBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final faqs = [
      {
        'question': 'Cum creez un profil?',
        'answer':
            'Pentru a crea un profil, accesează secțiunea "Profile" din meniul de jos, apoi apasă pe butonul "+" pentru a adăuga un profil nou. Completează informațiile necesare și salvează.',
      },
      {
        'question': 'Cum accesez modulele?',
        'answer':
            'Pentru a accesa modulele, asigură-te că ai un profil activ selectat. Apoi, accesează secțiunea "Module" din meniul de jos.',
      },
      {
        'question': 'Cum schimb tema aplicației?',
        'answer':
            'Poți schimba tema aplicației accesând secțiunea "Setări" și activând/dezactivând modul întunecat.',
      },
      {
        'question': 'Ce trebuie să fac dacă am uitat parola?',
        'answer':
            'Pe pagina de login, apasă pe "Ai uitat parola?" și urmează instrucțiunile pentru a reseta parola.',
      },
      {
        'question': 'Cum șterg contul?',
        'answer':
            'Poți șterge contul din secțiunea "Contul meu". Găsește butonul "Șterge contul" și confirmă acțiunea.',
      },
      {
        'question': 'Aplicația este gratuită?',
        'answer':
            'Aplicația oferă atât un plan gratuit (standard) cât și un plan premium cu funcționalități suplimentare.',
      },
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark
                ? const Color(0xFF1B1B20)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Întrebări frecvente (FAQ)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: cs.onSurface,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return _FAQItem(
                      question: faq['question']!,
                      answer: faq['answer']!,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark
            ? const Color(0xFF0D0D10)
            : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        trailing: Icon(
          _isExpanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: cs.onSurface,
        ),
        children: [
          Text(
            widget.answer,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

