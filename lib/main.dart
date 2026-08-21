import 'dart:convert';
import 'dart:math' as math;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const paper = Color(0xFFF3F0E8);
const ink = Color(0xFF171715);
const accent = Color(0xFFE84E2C);
bool supabaseReady = false;
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> selectTheme(ThemeMode mode) async {
  themeMode.value = mode;
  await SharedPreferencesAsync().setString('theme_mode', mode.name);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rectogwhppvcnpvmngbn.supabase.co',
  );
  const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_3r126Ki9aqsp7OOd37vqIA_ah3rIyX9',
  );
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    supabaseReady = true;
  }
  final savedTheme = await SharedPreferencesAsync().getString('theme_mode');
  themeMode.value = ThemeMode.values.firstWhere(
    (mode) => mode.name == savedTheme,
    orElse: () => ThemeMode.system,
  );
  runApp(const FamilyFlixApp());
}

class FamilyFlixApp extends StatelessWidget {
  const FamilyFlixApp({super.key});

  ThemeData _theme({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: dark ? const Color(0xFF1B1B18) : paper,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? const Color(0xFF121210) : paper,
      colorScheme: scheme,
      cardColor: dark ? const Color(0xFF24241F) : null,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: dark ? scheme.onSurface : ink,
          fontSize: 17,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          color: dark ? scheme.onSurfaceVariant : const Color(0xFF5D5A53),
          fontSize: 16,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: dark ? scheme.onSurfaceVariant : const Color(0xFF68645D),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'FamilyFlix',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        if (mediaQuery.size.width >= 600) return child!;
        final userScale = mediaQuery.textScaler.scale(1);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(userScale * 1.1),
          ),
          child: child!,
        );
      },
      themeMode: mode,
      theme: _theme(brightness: Brightness.light),
      darkTheme: _theme(brightness: Brightness.dark),
      home: const AuthGate(),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!supabaseReady) return const HomePage();
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.currentSession,
      ),
      builder: (context, snapshot) => snapshot.data?.session == null
          ? const AuthPage()
          : const HouseholdGate(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool createAccount = false;
  bool loading = false;
  bool obscurePassword = true;
  String? message;

  void selectMode(bool shouldCreateAccount) {
    if (loading || createAccount == shouldCreateAccount) return;
    setState(() {
      createAccount = shouldCreateAccount;
      message = null;
      obscurePassword = true;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final name = nameController.text.trim();
    if (!email.contains('@') || password.length < 8) {
      setState(
        () => message =
            'Saisissez un e-mail valide et un mot de passe de 8 caractères minimum.',
      );
      return;
    }
    if (createAccount && name.isEmpty) {
      setState(
        () => message = 'Indiquez le prénom ou le nom affiché dans la famille.',
      );
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });
    try {
      if (createAccount) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': name},
        );
        if (response.session == null && mounted) {
          setState(
            () => message =
                'Compte créé. Consultez votre e-mail pour confirmer votre adresse.',
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => message = _friendlyAuthError(error));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Connexion impossible pour le moment. Réessayez dans quelques instants.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _friendlyAuthError(AuthException error) {
    if (error.statusCode == '400') {
      return createAccount
          ? 'Ce compte existe peut-être déjà ou le mot de passe n’est pas accepté.'
          : 'E-mail ou mot de passe incorrect.';
    }
    if (error.statusCode == '429') {
      return 'Trop de tentatives. Patientez un instant avant de réessayer.';
    }
    return 'Authentification impossible : ${error.message}';
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(mobile ? 16 : 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                padding: EdgeInsets.all(mobile ? 22 : 36),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.center, child: Logo()),
                    const SizedBox(height: 30),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.login),
                          label: Text('Connexion'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.person_add_alt_1_outlined),
                          label: Text('Créer un compte'),
                        ),
                      ],
                      selected: {createAccount},
                      onSelectionChanged: (selection) =>
                          selectMode(selection.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 34),
                    Text(
                      createAccount
                          ? 'Créer votre accès'
                          : 'Heureux de vous revoir',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: mobile ? 32 : 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      createAccount
                          ? 'Créez votre compte, puis créez ou rejoignez votre famille.'
                          : 'Connectez-vous pour retrouver la vidéothèque de votre famille.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (createAccount) ...[
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Nom affiché',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onSubmitted: (_) => loading ? null : submit(),
                      autofillHints: createAccount
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        helperText: createAccount
                            ? '8 caractères minimum'
                            : null,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: obscurePassword
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                        ),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Color(0xFF8B2F1D),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: loading ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                      child: loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              createAccount
                                  ? 'Créer mon compte'
                                  : 'Se connecter',
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      createAccount
                          ? 'Après l’inscription, vous pourrez créer une famille ou en rejoindre une existante.'
                          : 'Votre collection reste privée et accessible uniquement aux membres de votre famille.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key});

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  HouseholdSummary? household;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadHousehold();
  }

  Future<void> loadHousehold() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser!;
      final membership = await client
          .from('household_members')
          .select(
            'display_name, role, '
            'households!household_members_household_id_fkey!inner(id, name)',
          )
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();

      if (membership == null) {
        if (mounted) {
          setState(() {
            household = null;
            loading = false;
          });
        }
        return;
      }

      final householdData = membership['households'] as Map<String, dynamic>;
      final householdId = householdData['id'] as String;
      final filmCount = await client
          .from('copies')
          .count(CountOption.exact)
          .eq('household_id', householdId);
      if (mounted) {
        setState(() {
          household = HouseholdSummary(
            id: householdId,
            name: householdData['name'] as String,
            displayName: membership['display_name'] as String,
            role: membership['role'] as String,
            filmCount: filmCount,
          );
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Impossible de charger votre famille pour le moment.';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: loadHousehold,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (household == null) {
      return HouseholdOnboardingPage(onChanged: loadHousehold);
    }
    return HomePage(household: household, onChanged: loadHousehold);
  }
}

class HouseholdOnboardingPage extends StatelessWidget {
  const HouseholdOnboardingPage({super.key, required this.onChanged});
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Logo(),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        TextButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
    body: PageWidth(
      child: Center(
        child: Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            _OnboardingCard(
              icon: Icons.add_home_outlined,
              title: 'Créer une famille',
              description: 'Démarrez une nouvelle vidéothèque familiale.',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CreateHouseholdPage(
                    onCreated: () async {
                      Navigator.of(context).pop();
                      await onChanged();
                    },
                  ),
                ),
              ),
            ),
            _OnboardingCard(
              icon: Icons.group_add_outlined,
              title: 'Rejoindre une famille',
              description: 'Utilisez son numéro et son mot de passe.',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => JoinHouseholdPage(onJoined: onChanged),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: accent),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

class JoinHouseholdPage extends StatefulWidget {
  const JoinHouseholdPage({super.key, required this.onJoined});
  final Future<void> Function() onJoined;

  @override
  State<JoinHouseholdPage> createState() => _JoinHouseholdPageState();
}

class _JoinHouseholdPageState extends State<JoinHouseholdPage> {
  final numberController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    numberController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> join() async {
    if (numberController.text.trim().length != 8 ||
        passwordController.text.length < 8 ||
        nameController.text.trim().isEmpty) {
      setState(
        () => error = 'Vérifiez le numéro, le mot de passe et votre nom.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'join_household_by_credentials',
        params: {
          'p_family_number': numberController.text.trim(),
          'p_password': passwordController.text,
          'p_display_name': nameController.text.trim(),
        },
      );
      await widget.onJoined();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Numéro ou mot de passe incorrect.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rejoindre une famille')),
    body: PageWidth(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Numéro de famille à 8 chiffres',
                ),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Votre nom dans la famille',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Color(0xFF8B2F1D))),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: loading ? null : join,
                child: Text(loading ? 'Connexion…' : 'Rejoindre'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CreateHouseholdPage extends StatefulWidget {
  const CreateHouseholdPage({super.key, required this.onCreated});
  final Future<void> Function() onCreated;

  @override
  State<CreateHouseholdPage> createState() => _CreateHouseholdPageState();
}

class _CreateHouseholdPageState extends State<CreateHouseholdPage> {
  late final TextEditingController householdController;
  late final TextEditingController displayNameController;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser!;
    final metadataName = user.userMetadata?['display_name'] as String?;
    final fallbackName = user.email?.split('@').first ?? '';
    displayNameController = TextEditingController(
      text: metadataName ?? fallbackName,
    );
    householdController = TextEditingController(
      text: metadataName == null || metadataName.isEmpty
          ? ''
          : 'Famille $metadataName',
    );
  }

  @override
  void dispose() {
    householdController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> createHousehold() async {
    final householdName = householdController.text.trim();
    final displayName = displayNameController.text.trim();
    if (householdName.isEmpty || displayName.isEmpty) {
      setState(
        () => error = 'Renseignez le nom de la famille et votre nom affiché.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'create_household',
        params: {'p_name': householdName, 'p_display_name': displayName},
      );
      await widget.onCreated();
    } on PostgrestException catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.code == '23505'
              ? 'Vous appartenez déjà à cette famille.'
              : 'La famille n’a pas pu être créée. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: Logo()),
                const SizedBox(height: 44),
                const Center(child: FamilyAvatar(filmCount: 0, size: 92)),
                const SizedBox(height: 16),
                const Text(
                  'Votre aventure commence',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 34),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Créez votre foyer. Son avatar évoluera automatiquement au fil de votre collection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 34),
                TextField(
                  controller: householdController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la famille',
                    hintText: 'Famille Audonnet',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: displayNameController,
                  onSubmitted: (_) => loading ? null : createHousehold(),
                  decoration: const InputDecoration(
                    labelText: 'Votre nom dans la famille',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF8B2F1D)),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: loading ? null : createHousehold,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  child: loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Créer ma famille'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.household, this.onChanged});
  final HouseholdSummary? household;
  final Future<void> Function()? onChanged;

  static const movies = [
    MoviePreview('Interstellar', '2014', 'Nicolas', Color(0xFF285574)),
    MoviePreview('Le Voyage de Chihiro', '2001', 'Marie', Color(0xFF2E7058)),
    MoviePreview('Retour vers le futur', '1985', 'Famille', Color(0xFFBD4B29)),
  ];

  void comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature arrive à la prochaine étape.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> openMovieSearch(BuildContext context) async {
    final currentHousehold = household;
    if (currentHousehold == null) {
      comingSoon(context, 'La recherche Internet');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MovieSearchPage(household: currentHousehold),
      ),
    );
    if (saved == true) await onChanged?.call();
  }

  Future<void> openMediaSources(BuildContext context) async {
    final currentHousehold = household;
    if (currentHousehold == null) {
      comingSoon(context, 'La gestion des supports');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaSourcesPage(household: currentHousehold),
      ),
    );
  }

  Future<void> openFamilyAccess(BuildContext context) async {
    final currentHousehold = household;
    if (currentHousehold == null ||
        (currentHousehold.role != 'owner' &&
            currentHousehold.role != 'admin')) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyAccessPage(household: currentHousehold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Header(
              onLogin: supabaseReady
                  ? () => Supabase.instance.client.auth.signOut()
                  : () => comingSoon(context, 'La connexion'),
              authenticated: supabaseReady,
              memberName: household?.displayName,
              familyName: household?.name,
              filmCount: household?.filmCount ?? 0,
              onManageFamily:
                  household?.role == 'owner' || household?.role == 'admin'
                  ? () => openFamilyAccess(context)
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: HeroSection(
              onAdd: () => openMovieSearch(context),
              onManageSources: () => openMediaSources(context),
            ),
          ),
          SliverToBoxAdapter(
            child: household == null
                ? Collection(
                    movies: movies,
                    onAdd: () => openMovieSearch(context),
                  )
                : FamilyLibrary(
                    household: household!,
                    onAdd: () => openMovieSearch(context),
                    onChanged: onChanged,
                  ),
          ),
          const SliverToBoxAdapter(child: FreePromise()),
        ],
      ),
    ),
  );
}

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key, required this.household});
  final HouseholdSummary household;

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final searchController = TextEditingController();
  final yearController = TextEditingController();
  List<TmdbMovie> results = const [];
  String mediaType = 'all';
  bool loading = false;
  String? error;

  @override
  void dispose() {
    searchController.dispose();
    yearController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = searchController.text.trim();
    final year = yearController.text.trim();
    if (query.length < 2) {
      setState(() => error = 'Saisissez au moins deux caractères.');
      return;
    }
    if (year.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(year)) {
      setState(() => error = 'L’année doit contenir quatre chiffres.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-search',
        body: {'query': query, 'media_type': mediaType, 'year': year},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawResults = data['results'] as List? ?? const [];
      if (mounted) {
        setState(() {
          results = rawResults
              .map(
                (item) =>
                    TmdbMovie.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();
          loading = false;
        });
      }
    } on FunctionException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.status == 503
            ? 'La connexion TMDB doit encore être configurée.'
            : 'La recherche Internet a échoué. Réessayez.';
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'La recherche Internet a échoué. Réessayez.';
        loading = false;
      });
    }
  }

  Future<void> chooseMovie(TmdbMovie movie) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SaveMovieSheet(household: widget.household, movie: movie),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Trouver un film ou une série'),
      backgroundColor: Theme.of(context).colorScheme.surface,
    ),
    body: PageWidth(
      child: Column(
        children: [
          const SizedBox(height: 22),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Tout')),
              ButtonSegment(
                value: 'movie',
                icon: Icon(Icons.movie_outlined),
                label: Text('Films'),
              ),
              ButtonSegment(
                value: 'tv',
                icon: Icon(Icons.tv_outlined),
                label: Text('Séries'),
              ),
            ],
            selected: {mediaType},
            onSelectionChanged: (value) {
              setState(() => mediaType = value.first);
              if (searchController.text.trim().length >= 2) search();
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 560;
              final titleField = TextField(
                controller: searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: const InputDecoration(
                  labelText: 'Titre du film ou de la série',
                  hintText: 'Ex. Le Seigneur des anneaux',
                  border: OutlineInputBorder(),
                ),
              );
              final yearField = TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: const InputDecoration(
                  labelText: 'Année',
                  hintText: '2024',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              );
              final searchButton = IconButton.filled(
                tooltip: 'Rechercher',
                onPressed: loading ? null : search,
                icon: const Icon(Icons.search),
              );
              if (mobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleField,
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: yearField),
                        const SizedBox(width: 10),
                        SizedBox(width: 56, height: 56, child: searchButton),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleField),
                  const SizedBox(width: 12),
                  SizedBox(width: 118, child: yearField),
                  const SizedBox(width: 8),
                  searchButton,
                ],
              );
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: Color(0xFF8B2F1D))),
          ],
          const SizedBox(height: 18),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: results.isEmpty && !loading
                ? const Center(
                    child: Text(
                      'Recherchez un film ou une série pour l’ajouter à votre\ncollection ou à vos souhaits.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final movie = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: movie.posterUrl == null
                            ? const SizedBox(
                                width: 54,
                                child: Icon(Icons.movie_outlined, size: 38),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Image.network(
                                  movie.posterUrl!,
                                  width: 54,
                                  height: 81,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 54,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                        title: Text(
                          movie.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            movie.year,
                            movie.overview,
                          ].where((part) => part.isNotEmpty).join(' · '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(movie.isSeries ? Icons.tv : Icons.movie),
                            Text(
                              movie.isSeries ? 'Série' : 'Film',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        onTap: () => chooseMovie(movie),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class SaveMovieSheet extends StatefulWidget {
  const SaveMovieSheet({
    super.key,
    required this.household,
    required this.movie,
  });
  final HouseholdSummary household;
  final TmdbMovie movie;

  @override
  State<SaveMovieSheet> createState() => _SaveMovieSheetState();
}

class _SaveMovieSheetState extends State<SaveMovieSheet> {
  String mode = 'copy';
  String format = 'bluray';
  String ownershipScope = 'complete_series';
  int selectedSeason = 1;
  Set<int> selectedSeasons = {1};
  List<int> availableSeasons = const [];
  bool loadingSeasons = false;
  String? mediaSourceId;
  List<MediaSource> mediaSources = const [];
  bool loadingSources = true;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMediaSources();
    if (widget.movie.isSeries) loadSeasons();
  }

  Future<void> loadSeasons() async {
    setState(() => loadingSeasons = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-details',
        body: {
          'items': [
            {'tmdb_id': widget.movie.tmdbId, 'media_type': 'tv'},
          ],
        },
      );
      final payload = Map<String, dynamic>.from(response.data as Map);
      final items = payload['movies'] as List? ?? const [];
      if (items.isEmpty || !mounted) return;
      final detail = Map<String, dynamic>.from(items.first as Map);
      final seasons =
          (detail['seasons'] as List? ?? const [])
              .map((item) => (item as Map)['number'] as int)
              .where((number) => number > 0)
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        availableSeasons = seasons;
        if (seasons.isNotEmpty) {
          selectedSeason = seasons.first;
          selectedSeasons = {seasons.first};
        }
        loadingSeasons = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingSeasons = false);
    }
  }

  Future<void> loadMediaSources() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('media_sources')
          .select('id, name, default_format, details')
          .eq('household_id', widget.household.id)
          .eq('is_active', true)
          .order('name');
      if (!mounted) return;
      setState(() {
        mediaSources = rows
            .map((row) => MediaSource.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        if (mediaSourceId != null &&
            !mediaSources.any((source) => source.id == mediaSourceId)) {
          mediaSourceId = null;
        }
        loadingSources = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingSources = false);
    }
  }

  Future<void> manageMediaSources() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaSourcesPage(household: widget.household),
      ),
    );
    if (mounted) await loadMediaSources();
  }

  Future<void> save() async {
    if (widget.movie.isSeries &&
        mode == 'copy' &&
        ownershipScope == 'selected_seasons' &&
        selectedSeasons.isEmpty) {
      setState(() => error = 'Sélectionnez au moins une saison.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final movieRow = await client
          .from('movies')
          .upsert(
            widget.movie.toDatabase(),
            onConflict: 'metadata_provider,media_type,tmdb_id',
          )
          .select('id')
          .single();
      final movieId = movieRow['id'] as String;

      if (mode == 'copy') {
        await client.from('copies').insert({
          'household_id': widget.household.id,
          'movie_id': movieId,
          'owner_id': userId,
          'format': format,
          'media_source_id': mediaSourceId,
          'ownership_scope': widget.movie.isSeries ? ownershipScope : 'movie',
          'season_numbers':
              !widget.movie.isSeries || ownershipScope == 'complete_series'
              ? null
              : ownershipScope == 'single_season'
              ? [selectedSeason]
              : (selectedSeasons.toList()..sort()),
        });
      } else {
        await client.from('watchlists').upsert({
          'household_id': widget.household.id,
          'user_id': userId,
          'movie_id': movieId,
          'state': 'to_watch',
        }, onConflict: 'household_id,user_id,movie_id');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible d’enregistrer ce contenu pour le moment.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      22,
      22,
      22 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.movie.title,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'copy',
                icon: Icon(Icons.video_library_outlined),
                label: Text('On le possède'),
              ),
              ButtonSegment(
                value: 'wish',
                icon: Icon(Icons.lightbulb_outline),
                label: Text('C’est un souhait'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (value) => setState(() => mode = value.first),
          ),
          if (mode == 'copy') ...[
            const SizedBox(height: 18),
            if (widget.movie.isSeries) ...[
              DropdownButtonFormField<String>(
                initialValue: ownershipScope,
                decoration: const InputDecoration(
                  labelText: 'Partie de la série possédée',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'complete_series',
                    child: Text('Série complète'),
                  ),
                  DropdownMenuItem(
                    value: 'single_season',
                    child: Text('Une saison particulière'),
                  ),
                  DropdownMenuItem(
                    value: 'selected_seasons',
                    child: Text('Plusieurs saisons'),
                  ),
                ],
                onChanged: (value) => setState(() => ownershipScope = value!),
              ),
              const SizedBox(height: 14),
              if (loadingSeasons)
                const LinearProgressIndicator()
              else if (ownershipScope == 'single_season')
                DropdownButtonFormField<int>(
                  initialValue: selectedSeason,
                  decoration: const InputDecoration(
                    labelText: 'Saison possédée',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      (availableSeasons.isEmpty ? const [1] : availableSeasons)
                          .map(
                            (number) => DropdownMenuItem(
                              value: number,
                              child: Text('Saison $number'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => selectedSeason = value!),
                )
              else if (ownershipScope == 'selected_seasons')
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Saisons possédées',
                    border: OutlineInputBorder(),
                  ),
                  child: Wrap(
                    spacing: 8,
                    children:
                        (availableSeasons.isEmpty
                                ? const [1]
                                : availableSeasons)
                            .map(
                              (number) => FilterChip(
                                label: Text('S$number'),
                                selected: selectedSeasons.contains(number),
                                onSelected: (selected) => setState(() {
                                  selected
                                      ? selectedSeasons.add(number)
                                      : selectedSeasons.remove(number);
                                }),
                              ),
                            )
                            .toList(),
                  ),
                ),
              const SizedBox(height: 14),
            ],
            if (loadingSources)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String?>(
                initialValue: mediaSourceId,
                decoration: const InputDecoration(
                  labelText: 'Support de la famille (facultatif)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Aucun support personnalisé'),
                  ),
                  ...mediaSources.map(
                    (source) => DropdownMenuItem<String?>(
                      value: source.id,
                      child: Text(source.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    mediaSourceId = value;
                    for (final source in mediaSources) {
                      if (source.id == value) {
                        format = source.defaultFormat;
                        break;
                      }
                    }
                  });
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: manageMediaSources,
                icon: const Icon(Icons.settings_outlined),
                label: Text(
                  widget.household.role == 'owner'
                      ? 'Gérer les supports de la famille'
                      : 'Voir les supports de la famille',
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(format),
              initialValue: format,
              decoration: const InputDecoration(
                labelText: 'Support',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'dvd', child: Text('DVD')),
                DropdownMenuItem(value: 'bluray', child: Text('Blu-ray')),
                DropdownMenuItem(value: 'bluray_4k', child: Text('Blu-ray 4K')),
                DropdownMenuItem(value: 'digital', child: Text('Numérique')),
                DropdownMenuItem(value: 'vhs', child: Text('VHS')),
                DropdownMenuItem(value: 'other', child: Text('Autre')),
              ],
              onChanged: (value) => setState(() => format = value!),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: Color(0xFF8B2F1D))),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: loading ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    mode == 'copy'
                        ? 'Ajouter à la collection'
                        : 'Ajouter à mes souhaits',
                  ),
          ),
        ],
      ),
    ),
  );
}

class FamilyAccessPage extends StatefulWidget {
  const FamilyAccessPage({super.key, required this.household});
  final HouseholdSummary household;

  @override
  State<FamilyAccessPage> createState() => _FamilyAccessPageState();
}

class _FamilyAccessPageState extends State<FamilyAccessPage> {
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final displayNameController = TextEditingController();
  String? familyNumber;
  String? message;
  bool loading = false;
  bool loadingMembers = true;
  List<FamilyMember> members = const [];

  @override
  void initState() {
    super.initState();
    loadNumber();
    loadMembers();
  }

  @override
  void dispose() {
    passwordController.dispose();
    emailController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> loadNumber() async {
    try {
      final value = await Supabase.instance.client.rpc(
        'get_family_join_number',
        params: {'p_household_id': widget.household.id},
      );
      if (mounted) setState(() => familyNumber = value as String?);
    } catch (_) {}
  }

  Future<void> loadMembers() async {
    try {
      final rows = await Supabase.instance.client
          .from('household_members')
          .select('user_id, display_name, role')
          .eq('household_id', widget.household.id)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        members = rows
            .map((row) => FamilyMember.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        loadingMembers = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMembers = false);
    }
  }

  Future<void> configureNumber() async {
    if (passwordController.text.length < 8) {
      setState(
        () => message = 'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final value = await Supabase.instance.client.rpc(
        'configure_family_join',
        params: {
          'p_household_id': widget.household.id,
          'p_password': passwordController.text,
        },
      );
      if (!mounted) return;
      setState(() {
        familyNumber = value as String;
        passwordController.clear();
        message = 'Accès familial enregistré.';
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          message = 'Impossible de configurer cet accès.';
          loading = false;
        });
      }
    }
  }

  Future<void> addByEmail() async {
    if (!emailController.text.contains('@') ||
        displayNameController.text.trim().isEmpty) {
      setState(() => message = 'Saisissez l’e-mail et le nom du membre.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'add_family_member_by_email',
        params: {
          'p_household_id': widget.household.id,
          'p_email': emailController.text.trim(),
          'p_display_name': displayNameController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        emailController.clear();
        displayNameController.clear();
        message = 'Le membre a été ajouté à la famille.';
        loading = false;
      });
      await loadMembers();
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        message = exception.message.contains('USER_NOT_FOUND')
            ? 'Cet utilisateur doit d’abord créer son compte FamilyFlix.'
            : exception.message.contains('USER_ALREADY_IN_FAMILY')
            ? 'Cet utilisateur appartient déjà à une famille.'
            : 'Impossible d’ajouter ce membre.';
        loading = false;
      });
    }
  }

  Future<void> changeRole(FamilyMember member) async {
    final newRole = member.role == 'admin' ? 'member' : 'admin';
    final action = newRole == 'admin'
        ? 'accorder les droits d’administrateur à'
        : 'retirer les droits d’administrateur de';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          newRole == 'admin'
              ? 'Nommer administrateur ?'
              : 'Rétrograder ce membre ?',
        ),
        content: Text('Voulez-vous $action ${member.displayName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        'set_family_member_role',
        params: {
          'p_household_id': widget.household.id,
          'p_user_id': member.userId,
          'p_role': newRole,
        },
      );
      await loadMembers();
      if (mounted) {
        setState(() {
          message = newRole == 'admin'
              ? '${member.displayName} est maintenant administrateur.'
              : '${member.displayName} est maintenant membre.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Impossible de modifier ce rôle.');
    }
  }

  Future<void> removeMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text(
          '${member.displayName} quittera la famille. Ses films, souhaits et avis seront retirés de cette famille.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.rpc(
        'remove_family_member',
        params: {
          'p_household_id': widget.household.id,
          'p_user_id': member.userId,
        },
      );
      await loadMembers();
      if (mounted) {
        setState(
          () => message = '${member.displayName} a été retiré de la famille.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Impossible de retirer ce membre.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gérer la famille')),
    body: PageWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 28),
        children: [
          const Text(
            'Rejoindre avec un numéro',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const SizedBox(height: 10),
          if (familyNumber != null)
            SelectableText(
              familyNumber!,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: accent,
              ),
            ),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: familyNumber == null
                  ? 'Définir le mot de passe familial'
                  : 'Changer le mot de passe familial',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: loading ? null : configureNumber,
              child: const Text('Enregistrer l’accès'),
            ),
          ),
          const Divider(height: 56),
          const Text(
            'Ajouter un utilisateur par e-mail',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const Text(
            'L’utilisateur doit avoir créé son compte FamilyFlix auparavant.',
          ),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail du membre'),
          ),
          TextField(
            controller: displayNameController,
            decoration: const InputDecoration(
              labelText: 'Nom affiché dans la famille',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: loading ? null : addByEmail,
              child: const Text('Ajouter le membre'),
            ),
          ),
          const Divider(height: 56),
          const Text(
            'Membres de la famille',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const SizedBox(height: 12),
          if (loadingMembers)
            const Center(child: CircularProgressIndicator())
          else
            ...members.map(
              (member) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      member.displayName.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(member.displayName),
                  subtitle: Text(member.roleLabel),
                  trailing:
                      widget.household.role == 'owner' && member.role != 'owner'
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'role') changeRole(member);
                            if (value == 'remove') removeMember(member);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'role',
                              child: Text(
                                member.role == 'admin'
                                    ? 'Retirer les droits admin'
                                    : 'Nommer administrateur',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Retirer de la famille'),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          if (message != null) ...[const SizedBox(height: 18), Text(message!)],
        ],
      ),
    ),
  );
}

class MediaSourcesPage extends StatefulWidget {
  const MediaSourcesPage({super.key, required this.household});
  final HouseholdSummary household;

  @override
  State<MediaSourcesPage> createState() => _MediaSourcesPageState();
}

class _MediaSourcesPageState extends State<MediaSourcesPage> {
  bool loading = true;
  String? error;
  List<MediaSource> sources = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('media_sources')
          .select('id, name, default_format, details')
          .eq('household_id', widget.household.id)
          .eq('is_active', true)
          .order('name');
      if (!mounted) return;
      setState(() {
        sources = rows
            .map((row) => MediaSource.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les supports de la famille.';
        loading = false;
      });
    }
  }

  Future<void> addSource() async {
    if (widget.household.role != 'owner') return;
    final draft = await showDialog<MediaSourceDraft>(
      context: context,
      builder: (_) => const MediaSourceDialog(),
    );
    if (draft == null) return;
    try {
      final client = Supabase.instance.client;
      await client.from('media_sources').insert({
        'household_id': widget.household.id,
        'owner_id': client.auth.currentUser!.id,
        'name': draft.name,
        'default_format': draft.defaultFormat,
        'details': draft.details.isEmpty ? null : draft.details,
      });
      await load();
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      final message = exception.code == '23505'
          ? 'Ce support existe déjà dans la famille.'
          : 'Impossible d’ajouter ce support.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> deleteSource(MediaSource source) async {
    if (widget.household.role != 'owner') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce support ?'),
        content: Text(
          '“${source.name}” sera retiré de la famille. Les films resteront dans la vidéothèque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client
        .from('media_sources')
        .delete()
        .eq('id', source.id);
    await load();
  }

  Future<void> transferSources() async {
    if (sources.length < 2) return;
    final transfer = await showDialog<MediaTransferDraft>(
      context: context,
      builder: (_) => MediaTransferDialog(
        sources: sources,
        canTransferFamily:
            widget.household.role == 'owner' ||
            widget.household.role == 'admin',
      ),
    );
    if (transfer == null) return;

    final source = sources.firstWhere((item) => item.id == transfer.sourceId);
    final destination = sources.firstWhere(
      (item) => item.id == transfer.destinationId,
    );
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le transfert'),
        content: Text(
          'Les contenus de “${source.name}” seront déplacés vers “${destination.name}”. '
          '${transfer.forFamily ? 'Cela concerne toute la famille.' : 'Cela concerne uniquement vos exemplaires.'}\n\n'
          'Les fiches existantes seront modifiées : aucun film ni aucune série ne sera dupliqué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transférer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await Supabase.instance.client.rpc(
        'transfer_media_source',
        params: {
          'p_household_id': widget.household.id,
          'p_source_id': transfer.sourceId,
          'p_destination_id': transfer.destinationId,
          'p_for_family': transfer.forFamily,
          'p_update_format': transfer.updateFormat,
        },
      );
      if (!mounted) return;
      final count = result as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Aucun contenu à transférer depuis “${source.name}”.'
                : '$count contenu${count > 1 ? 's ont' : ' a'} été transféré${count > 1 ? 's' : ''} vers “${destination.name}”, sans duplication.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le transfert n’a pas pu être effectué.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Supports de la famille'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actions: [
        IconButton(
          tooltip: 'Transférer plusieurs contenus',
          onPressed: sources.length < 2 ? null : transferSources,
          icon: const Icon(Icons.drive_file_move_outline),
        ),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButton: widget.household.role == 'owner'
        ? FloatingActionButton.extended(
            onPressed: addSource,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          )
        : null,
    body: PageWidth(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : sources.isEmpty
          ? Center(
              child: Text(
                widget.household.role == 'owner'
                    ? 'Ajoutez les emplacements de la famille : NAS, box, disque dur, étagère…'
                    : 'Le créateur de la famille n’a pas encore ajouté de support.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 22),
              itemCount: sources.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final source = sources[index];
                return ListTile(
                  leading: Icon(source.icon),
                  title: Text(
                    source.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      source.formatLabel,
                      source.details,
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                  trailing: widget.household.role == 'owner'
                      ? IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => deleteSource(source),
                          icon: const Icon(Icons.delete_outline),
                        )
                      : null,
                );
              },
            ),
    ),
  );
}

class MediaTransferDialog extends StatefulWidget {
  const MediaTransferDialog({
    super.key,
    required this.sources,
    required this.canTransferFamily,
  });

  final List<MediaSource> sources;
  final bool canTransferFamily;

  @override
  State<MediaTransferDialog> createState() => _MediaTransferDialogState();
}

class _MediaTransferDialogState extends State<MediaTransferDialog> {
  late String sourceId;
  late String destinationId;
  bool forFamily = false;
  bool updateFormat = true;

  @override
  void initState() {
    super.initState();
    sourceId = widget.sources.first.id;
    destinationId = widget.sources[1].id;
  }

  MediaSource get destination =>
      widget.sources.firstWhere((source) => source.id == destinationId);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Transférer plusieurs contenus'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Déplacez rapidement tous les exemplaires concernés vers un autre support. Les fiches seront mises à jour sans être dupliquées.',
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              initialValue: sourceId,
              decoration: const InputDecoration(
                labelText: 'Support de départ',
                prefixIcon: Icon(Icons.logout),
              ),
              items: [
                for (final source in widget.sources)
                  DropdownMenuItem(value: source.id, child: Text(source.name)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  sourceId = value;
                  if (destinationId == sourceId) {
                    destinationId = widget.sources
                        .firstWhere((source) => source.id != sourceId)
                        .id;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('destination-$sourceId-$destinationId'),
              initialValue: destinationId,
              decoration: const InputDecoration(
                labelText: 'Support de destination',
                prefixIcon: Icon(Icons.login),
              ),
              items: [
                for (final source in widget.sources)
                  if (source.id != sourceId)
                    DropdownMenuItem(
                      value: source.id,
                      child: Text(source.name),
                    ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => destinationId = value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: updateFormat,
              contentPadding: EdgeInsets.zero,
              title: const Text('Appliquer le type du support destination'),
              subtitle: Text(
                'Les contenus deviendront “${destination.formatLabel}”.',
              ),
              onChanged: (value) => setState(() => updateFormat = value),
            ),
            if (widget.canTransferFamily)
              SwitchListTile(
                value: forFamily,
                contentPadding: EdgeInsets.zero,
                title: const Text('Transférer pour toute la famille'),
                subtitle: const Text(
                  'Inclut également les exemplaires des autres membres.',
                ),
                onChanged: (value) => setState(() => forFamily = value),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton.icon(
        onPressed: sourceId == destinationId
            ? null
            : () => Navigator.pop(
                context,
                MediaTransferDraft(
                  sourceId: sourceId,
                  destinationId: destinationId,
                  forFamily: forFamily,
                  updateFormat: updateFormat,
                ),
              ),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Continuer'),
      ),
    ],
  );
}

class MediaSourceDialog extends StatefulWidget {
  const MediaSourceDialog({super.key});

  @override
  State<MediaSourceDialog> createState() => _MediaSourceDialogState();
}

class _MediaSourceDialogState extends State<MediaSourceDialog> {
  final nameController = TextEditingController();
  final detailsController = TextEditingController();
  String defaultFormat = 'digital';

  @override
  void dispose() {
    nameController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter un support'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nom',
              hintText: 'Ex. NAS Nicolas',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: defaultFormat,
            decoration: const InputDecoration(labelText: 'Type par défaut'),
            items: const [
              DropdownMenuItem(value: 'dvd', child: Text('DVD')),
              DropdownMenuItem(value: 'bluray', child: Text('Blu-ray')),
              DropdownMenuItem(value: 'bluray_4k', child: Text('Blu-ray 4K')),
              DropdownMenuItem(
                value: 'digital',
                child: Text('Numérique / réseau'),
              ),
              DropdownMenuItem(value: 'vhs', child: Text('VHS')),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
            ],
            onChanged: (value) => setState(() => defaultFormat = value!),
          ),
          TextField(
            controller: detailsController,
            maxLength: 240,
            decoration: const InputDecoration(
              labelText: 'Détails facultatifs',
              hintText: 'Ex. dossier /Films ou box du salon',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final name = nameController.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(
            context,
            MediaSourceDraft(
              name: name,
              defaultFormat: defaultFormat,
              details: detailsController.text.trim(),
            ),
          );
        },
        child: const Text('Ajouter'),
      ),
    ],
  );
}

class MediaSource {
  const MediaSource({
    required this.id,
    required this.name,
    required this.defaultFormat,
    required this.details,
  });

  factory MediaSource.fromJson(Map<String, dynamic> json) => MediaSource(
    id: json['id'] as String,
    name: json['name'] as String,
    defaultFormat: json['default_format'] as String,
    details: json['details'] as String? ?? '',
  );

  final String id;
  final String name;
  final String defaultFormat;
  final String details;

  String get formatLabel => switch (defaultFormat) {
    'dvd' => 'DVD',
    'bluray' => 'Blu-ray',
    'bluray_4k' => 'Blu-ray 4K',
    'digital' => 'Numérique / réseau',
    'vhs' => 'VHS',
    _ => 'Autre',
  };

  IconData get icon => switch (defaultFormat) {
    'digital' => Icons.dns_outlined,
    'dvd' || 'bluray' || 'bluray_4k' => Icons.album_outlined,
    'vhs' => Icons.video_camera_back_outlined,
    _ => Icons.inventory_2_outlined,
  };
}

class MediaSourceDraft {
  const MediaSourceDraft({
    required this.name,
    required this.defaultFormat,
    required this.details,
  });

  final String name;
  final String defaultFormat;
  final String details;
}

class MediaTransferDraft {
  const MediaTransferDraft({
    required this.sourceId,
    required this.destinationId,
    required this.forFamily,
    required this.updateFormat,
  });

  final String sourceId;
  final String destinationId;
  final bool forFamily;
  final bool updateFormat;
}

class TmdbMovie {
  const TmdbMovie({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.releaseDate,
    required this.posterPath,
  });

  factory TmdbMovie.fromJson(Map<String, dynamic> json) => TmdbMovie(
    tmdbId: json['tmdb_id'] as int,
    mediaType: json['media_type'] as String? ?? 'movie',
    title: json['title'] as String? ?? 'Sans titre',
    originalTitle: json['original_title'] as String?,
    overview: json['overview'] as String? ?? '',
    releaseDate: json['release_date'] as String?,
    posterPath: json['poster_path'] as String?,
  );

  final int tmdbId;
  final String mediaType;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? releaseDate;
  final String? posterPath;

  String get year => releaseDate?.split('-').first ?? '';
  bool get isSeries => mediaType == 'tv';
  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w185$posterPath';

  Map<String, dynamic> toDatabase() => {
    'tmdb_id': tmdbId,
    'media_type': mediaType,
    'title': title,
    'original_title': originalTitle,
    'overview': overview,
    'release_date': releaseDate,
    'poster_path': posterPath,
    'metadata_provider': 'tmdb',
    'metadata_updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 22),
          child: child,
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.onLogin,
    this.authenticated = false,
    this.memberName,
    this.familyName,
    this.filmCount = 0,
    this.onManageFamily,
  });
  final VoidCallback onLogin;
  final bool authenticated;
  final String? memberName;
  final String? familyName;
  final int filmCount;
  final VoidCallback? onManageFamily;

  void _selectAccountAction(BuildContext context, String action) {
    if (action == 'logout') {
      onLogin();
      return;
    }
    if (action == 'family') {
      onManageFamily?.call();
      return;
    }
    final selectedTheme = switch (action) {
      'theme-light' => ThemeMode.light,
      'theme-dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    selectTheme(selectedTheme);
  }

  List<PopupMenuEntry<String>> _accountMenu(BuildContext context) => [
    PopupMenuItem<String>(
      enabled: false,
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName ?? 'Compte FamilyFlix',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (familyName != null) ...[
              const SizedBox(height: 3),
              Text(
                familyName!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text('$filmCount contenu${filmCount > 1 ? 's' : ''}'),
          ],
        ),
      ),
    ),
    const PopupMenuDivider(),
    if (onManageFamily != null) ...[
      const PopupMenuItem(
        value: 'family',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.manage_accounts_outlined),
          title: Text('Gérer la famille'),
        ),
      ),
      const PopupMenuDivider(),
    ],
    const PopupMenuItem(
      value: 'theme-system',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.brightness_auto_outlined),
        title: Text('Thème du système'),
      ),
    ),
    const PopupMenuItem(
      value: 'theme-light',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.light_mode_outlined),
        title: Text('Thème clair'),
      ),
    ),
    const PopupMenuItem(
      value: 'theme-dark',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.dark_mode_outlined),
        title: Text('Thème sombre'),
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: 'logout',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.logout),
        title: Text('Se déconnecter'),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => PageWidth(
    child: Container(
      height: 82,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2E171715))),
      ),
      child: Row(
        children: [
          const Logo(),
          const Spacer(),
          if (!authenticated)
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeMode,
              builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
                tooltip: 'Choisir le thème',
                initialValue: mode,
                onSelected: selectTheme,
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : mode == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : Icons.brightness_auto_outlined,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ThemeMode.system,
                    child: Text('Thème du système'),
                  ),
                  PopupMenuItem(
                    value: ThemeMode.light,
                    child: Text('Thème clair'),
                  ),
                  PopupMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Thème sombre'),
                  ),
                ],
              ),
            ),
          if (!authenticated && MediaQuery.sizeOf(context).width > 420)
            TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(
                authenticated ? 'Se déconnecter' : 'Se connecter',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          if (authenticated) ...[
            if (memberName != null && MediaQuery.sizeOf(context).width > 620)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  memberName!,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: 'Ouvrir le menu du compte',
              onSelected: (action) => _selectAccountAction(context, action),
              itemBuilder: _accountMenu,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FamilyAvatar(filmCount: filmCount, size: 48),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class FamilyAvatar extends StatelessWidget {
  const FamilyAvatar({super.key, required this.filmCount, this.size = 48});
  final int filmCount;
  final double size;

  AvatarStage get stage {
    if (filmCount >= 100) {
      return const AvatarStage(
        Icons.emoji_events,
        Color(0xFF7B3FA0),
        'Légende familiale',
      );
    }
    if (filmCount >= 50) {
      return const AvatarStage(
        Icons.theater_comedy,
        Color(0xFFB2432D),
        'Cinéphiles confirmés',
      );
    }
    if (filmCount >= 25) {
      return const AvatarStage(
        Icons.movie_filter,
        Color(0xFF285574),
        'Collectionneurs',
      );
    }
    if (filmCount >= 10) {
      return const AvatarStage(
        Icons.local_activity,
        Color(0xFF2E7058),
        'Soirée popcorn',
      );
    }
    if (filmCount >= 1) {
      return const AvatarStage(
        Icons.local_movies_outlined,
        Color(0xFFBD4B29),
        'Premières bobines',
      );
    }
    return const AvatarStage(Icons.auto_awesome, accent, 'L’aventure commence');
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${stage.label} · $filmCount film${filmCount > 1 ? 's' : ''}',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: stage.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: .75),
          width: size > 60 ? 4 : 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(stage.icon, color: Colors.white, size: size * .48),
    ),
  );
}

class AvatarStage {
  const AvatarStage(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Family',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const TextSpan(
            text: 'Flix',
            style: TextStyle(color: accent),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: mobile ? 29 : 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.4,
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.onAdd,
    required this.onManageSources,
  });
  final VoidCallback onAdd;
  final VoidCallback onManageSources;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return PageWidth(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 54 : 82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Kicker('NOTRE CINÉMA, À LA MAISON', withLine: true),
            const SizedBox(height: 22),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Tous vos films.\n'),
                  TextSpan(
                    text: 'Toute votre famille.',
                    style: TextStyle(
                      color: accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: mobile ? 42 : 88,
                height: .94,
                letterSpacing: mobile ? -1.5 : -4,
              ),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: const Text(
                'Une vidéothèque simple et privée pour savoir qui possède quoi, et choisir ensemble le prochain film.',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF55534C),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 12 : 22,
                      vertical: 18,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  child: const Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(Icons.add, size: 19),
                      Text('Ajouter un film ou une série'),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: onManageSources,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  child: const Text('Supports de la famille'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Collection extends StatelessWidget {
  const Collection({super.key, required this.movies, required this.onAdd});
  final List<MoviePreview> movies;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: Color(0x2E171715)),
      ),
    ),
    child: PageWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('DERNIERS AJOUTS'),
                const SizedBox(height: 8),
                const Text(
                  'Dans la vidéothèque',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 39),
                ),
                const SizedBox(height: 28),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: movies.length + 1,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 26,
                    childAspectRatio: .60,
                  ),
                  itemBuilder: (context, index) => index < movies.length
                      ? MovieCard(movie: movies[index], number: index + 1)
                      : AddMovieCard(onTap: onAdd),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class FamilyLibrary extends StatefulWidget {
  const FamilyLibrary({
    super.key,
    required this.household,
    required this.onAdd,
    this.onChanged,
  });

  final HouseholdSummary household;
  final VoidCallback onAdd;
  final Future<void> Function()? onChanged;

  @override
  State<FamilyLibrary> createState() => _FamilyLibraryState();
}

class _FamilyLibraryState extends State<FamilyLibrary> {
  bool loading = true;
  String? error;
  List<LibraryMovie> copies = const [];
  List<LibraryMovie> wishes = const [];
  String mediaTypeFilter = 'all';
  String formatFilter = 'all';
  String genreFilter = 'all';
  String ageFilter = 'all';
  String yearFilter = 'all';
  String sortOrder = 'recent';
  String titleQuery = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final responses = await Future.wait([
        client
            .from('copies')
            .select(
              'id, owner_id, format, ownership_scope, season_numbers, movies!copies_movie_id_fkey(id, tmdb_id, media_type, title, overview, release_date, poster_path), '
              'household_members!copies_household_id_owner_id_fkey(display_name), '
              'media_sources!copies_media_source_scope_fkey(name)',
            )
            .eq('household_id', widget.household.id)
            .order('created_at', ascending: false),
        client
            .from('watchlists')
            .select(
              'movies!watchlists_movie_id_fkey(id, tmdb_id, media_type, title, overview, release_date, poster_path), '
              'household_members!watchlists_household_id_user_id_fkey(display_name)',
            )
            .eq('household_id', widget.household.id)
            .eq('state', 'to_watch')
            .order('created_at', ascending: false),
      ]);

      final parsedCopies = (responses[0] as List)
          .map(
            (row) =>
                LibraryMovie.fromCopy(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      final parsedWishes = (responses[1] as List)
          .map(
            (row) =>
                LibraryMovie.fromWish(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      final details = await loadTmdbDetails([...parsedCopies, ...parsedWishes]);
      if (!mounted) return;
      setState(() {
        copies = parsedCopies
            .map((movie) => movie.withDetails(details[movie.tmdbKey]))
            .toList();
        wishes = parsedWishes
            .map((movie) => movie.withDetails(details[movie.tmdbKey]))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger la vidéothèque de la famille.';
        loading = false;
      });
    }
  }

  Future<Map<String, TmdbMovieDetails>> loadTmdbDetails(
    List<LibraryMovie> media,
  ) async {
    final uniqueMedia = <String, LibraryMovie>{
      for (final item in media) item.tmdbKey: item,
    }.values.toList();
    final details = <String, TmdbMovieDetails>{};
    try {
      for (var start = 0; start < uniqueMedia.length; start += 50) {
        final end = (start + 50).clamp(0, uniqueMedia.length);
        final response = await Supabase.instance.client.functions.invoke(
          'tmdb-details',
          body: {
            'items': uniqueMedia
                .sublist(start, end)
                .map(
                  (item) => {
                    'tmdb_id': item.tmdbId,
                    'media_type': item.mediaType,
                  },
                )
                .toList(),
          },
        );
        final payload = Map<String, dynamic>.from(response.data as Map);
        for (final item in payload['movies'] as List? ?? const []) {
          final detail = TmdbMovieDetails.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          details[detail.tmdbKey] = detail;
        }
      }
    } catch (_) {
      // La vidéothèque locale reste utilisable si TMDB est momentanément absent.
    }
    return details;
  }

  List<LibraryMovie> get filteredCopies {
    final result = copies.where((movie) {
      final titleMatches =
          titleQuery.trim().isEmpty ||
          movie.title.toLowerCase().contains(titleQuery.trim().toLowerCase());
      final mediaTypeMatches =
          mediaTypeFilter == 'all' || movie.mediaType == mediaTypeFilter;
      final formatMatches =
          formatFilter == 'all' || movie.format == formatFilter;
      final genreMatches =
          genreFilter == 'all' || movie.genres.contains(genreFilter);
      final ageMatches = ageFilter == 'all' || movie.ageCategory == ageFilter;
      final yearMatches = yearFilter == 'all' || movie.year == yearFilter;
      return titleMatches &&
          mediaTypeMatches &&
          formatMatches &&
          genreMatches &&
          ageMatches &&
          yearMatches;
    }).toList();
    if (sortOrder == 'title') {
      result.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else if (sortOrder == 'year') {
      result.sort((a, b) => b.year.compareTo(a.year));
    } else if (sortOrder == 'age') {
      result.sort((a, b) => a.ageSortValue.compareTo(b.ageSortValue));
    }
    return result;
  }

  List<String> get availableGenres =>
      copies.expand((movie) => movie.genres).toSet().toList()..sort();

  List<String> get availableAges =>
      copies
          .map((movie) => movie.ageCategory)
          .where((age) => age != 'unknown')
          .toSet()
          .toList()
        ..sort(
          (a, b) =>
              LibraryMovie.ageValue(a).compareTo(LibraryMovie.ageValue(b)),
        );

  List<String> get availableYears =>
      copies
          .map((movie) => movie.year)
          .where((year) => year.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  Future<void> openCatalog() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FamilyCatalogPage(household: widget.household, movies: copies),
      ),
    );
  }

  Future<void> deleteCopy(LibraryMovie movie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer ${movie.typeLabel.toLowerCase()} ?'),
        content: Text(
          '“${movie.title}” sera retiré de votre vidéothèque. Les souhaits et avis éventuels seront conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('copies')
          .delete()
          .eq('id', movie.copyId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“${movie.title}” a été retiré.')));
      await load();
      await widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer ce contenu.')),
      );
    }
  }

  Future<void> openMovie(LibraryMovie movie) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MovieDetailPage(household: widget.household, movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: Color(0x2E171715)),
      ),
    ),
    child: PageWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  children: [
                    Text(error!),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: load,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Kicker('VIDÉOTHÈQUE FAMILIALE'),
                  const SizedBox(height: 8),
                  const Text(
                    'Les films et séries que vous possédez',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 36),
                  ),
                  const SizedBox(height: 22),
                  if (copies.isEmpty)
                    EmptyLibraryMessage(onAdd: widget.onAdd)
                  else ...[
                    Autocomplete<String>(
                      optionsBuilder: (value) {
                        final query = value.text.trim().toLowerCase();
                        if (query.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return copies
                            .map((movie) => movie.title)
                            .toSet()
                            .where(
                              (title) => title.toLowerCase().contains(query),
                            )
                            .take(8);
                      },
                      onSelected: (title) => setState(() => titleQuery = title),
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (value) =>
                                  setState(() => titleQuery = value),
                              onSubmitted: (_) => onSubmitted(),
                              decoration: InputDecoration(
                                labelText: 'Rechercher dans la vidéothèque',
                                hintText: 'Commencez à saisir le titre…',
                                prefixIcon: const Icon(Icons.search, size: 30),
                                suffixIcon: titleQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Effacer la recherche',
                                        onPressed: () {
                                          controller.clear();
                                          setState(() => titleQuery = '');
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 22,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) =>
                          Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                  maxHeight: 340,
                                ),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: [
                                    for (final title in options)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.movie_outlined,
                                        ),
                                        title: Text(title),
                                        onTap: () => onSelected(title),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 18),
                    LibraryFilters(
                      mediaType: mediaTypeFilter,
                      format: formatFilter,
                      genre: genreFilter,
                      age: ageFilter,
                      year: yearFilter,
                      sort: sortOrder,
                      genres: availableGenres,
                      ages: availableAges,
                      years: availableYears,
                      onMediaTypeChanged: (value) =>
                          setState(() => mediaTypeFilter = value),
                      onFormatChanged: (value) =>
                          setState(() => formatFilter = value),
                      onGenreChanged: (value) =>
                          setState(() => genreFilter = value),
                      onAgeChanged: (value) =>
                          setState(() => ageFilter = value),
                      onYearChanged: (value) =>
                          setState(() => yearFilter = value),
                      onSortChanged: (value) =>
                          setState(() => sortOrder = value),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: openCatalog,
                      icon: const Icon(Icons.table_rows_outlined),
                      label: const Text('Voir toute la collection en tableau'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${filteredCopies.length} contenu${filteredCopies.length > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 10),
                    if (filteredCopies.isEmpty)
                      const Text('Aucun contenu ne correspond à ces filtres.')
                    else
                      MovieStrip(
                        movies: filteredCopies,
                        canDeleteAny:
                            widget.household.role == 'owner' ||
                            widget.household.role == 'admin',
                        onDelete: deleteCopy,
                        onOpen: openMovie,
                      ),
                  ],
                  const SizedBox(height: 52),
                  const Kicker('IDÉES DES MEMBRES'),
                  const SizedBox(height: 8),
                  const Text(
                    'Les souhaits de la famille',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 36),
                  ),
                  const SizedBox(height: 22),
                  if (wishes.isEmpty)
                    const Text(
                      'Aucun souhait pour le moment. Utilisez “Ajouter” pour proposer une idée.',
                    )
                  else
                    MovieStrip(movies: wishes, wish: true, onOpen: openMovie),
                ],
              ),
      ),
    ),
  );
}

class FamilyCatalogPage extends StatefulWidget {
  const FamilyCatalogPage({
    super.key,
    required this.household,
    required this.movies,
  });

  final HouseholdSummary household;
  final List<LibraryMovie> movies;

  @override
  State<FamilyCatalogPage> createState() => FamilyCatalogPageState();
}

class FamilyCatalogPageState extends State<FamilyCatalogPage> {
  String mediaType = 'all';
  String format = 'all';
  String genre = 'all';
  String age = 'all';
  String year = 'all';
  String sort = 'title';
  bool exporting = false;

  static String formatPrintDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year}';
  }

  List<String> get genres =>
      widget.movies.expand((movie) => movie.genres).toSet().toList()..sort();
  List<String> get ages =>
      widget.movies
          .map((movie) => movie.ageCategory)
          .where((value) => value != 'unknown')
          .toSet()
          .toList()
        ..sort(
          (a, b) =>
              LibraryMovie.ageValue(a).compareTo(LibraryMovie.ageValue(b)),
        );
  List<String> get years =>
      widget.movies
          .map((movie) => movie.year)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  List<LibraryMovie> get filteredMovies {
    final result = widget.movies.where((movie) {
      return (mediaType == 'all' || movie.mediaType == mediaType) &&
          (format == 'all' || movie.format == format) &&
          (genre == 'all' || movie.genres.contains(genre)) &&
          (age == 'all' || movie.ageCategory == age) &&
          (year == 'all' || movie.year == year);
    }).toList();
    switch (sort) {
      case 'title':
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'year':
        result.sort((a, b) => b.year.compareTo(a.year));
      case 'age':
        result.sort((a, b) => a.ageSortValue.compareTo(b.ageSortValue));
    }
    return result;
  }

  String csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final rows = <List<String>>[
        [
          'Titre',
          'Type',
          'Année',
          'Propriétaire',
          'Support',
          'Emplacement',
          'Possession',
          'Genres',
          'Âge conseillé',
        ],
        for (final movie in filteredMovies)
          [
            movie.title,
            movie.typeLabel,
            movie.year,
            movie.member,
            movie.formatLabel,
            movie.sourceName,
            movie.isSeries ? movie.ownershipLabel : 'Film complet',
            movie.genres.join(' | '),
            LibraryMovie.ageLabel(movie.ageCategory),
          ],
      ];
      final csv = rows.map((row) => row.map(csvCell).join(';')).join('\r\n');
      await FileSaver.instance.saveFile(
        name:
            'familyflix-${widget.household.name.toLowerCase().replaceAll(' ', '-')}',
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<Uint8List> buildPdf(PdfPageFormat format) async {
    final printDate = formatPrintDate(DateTime.now());
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
    );
    final document = pw.Document(
      title: 'Catalogue FamilyFlix - ${widget.household.name}',
      author: 'FamilyFlix',
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final rows = [
      for (final movie in filteredMovies)
        [
          movie.title,
          movie.typeLabel,
          movie.year,
          movie.member,
          movie.formatLabel,
          movie.isSeries ? movie.ownershipLabel : 'Film complet',
        ],
    ];
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FamilyFlix',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#E84E2C'),
              ),
            ),
            pw.Text(
              'Catalogue de ${widget.household.name} - ${rows.length} contenu${rows.length > 1 ? 's' : ''}',
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Imprimé le $printDate',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#5D5A53'),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}'),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'Titre',
              'Type',
              'Année',
              'Propriétaire',
              'Support',
              'Possession',
            ],
            data: rows,
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#171715'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(6),
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F3F0E8'),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.3),
              1: pw.FlexColumnWidth(.7),
              2: pw.FlexColumnWidth(.7),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(1.5),
            },
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> exportPdf() async {
    setState(() => exporting = true);
    try {
      await Printing.layoutPdf(
        name: 'familyflix-${widget.household.name}.pdf',
        onLayout: buildPdf,
      );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catalogue complet')),
    body: PageWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Text(
            widget.household.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          LibraryFilters(
            mediaType: mediaType,
            format: format,
            genre: genre,
            age: age,
            year: year,
            sort: sort,
            genres: genres,
            ages: ages,
            years: years,
            onMediaTypeChanged: (value) => setState(() => mediaType = value),
            onFormatChanged: (value) => setState(() => format = value),
            onGenreChanged: (value) => setState(() => genre = value),
            onAgeChanged: (value) => setState(() => age = value),
            onYearChanged: (value) => setState(() => year = value),
            onSortChanged: (value) => setState(() => sort = value),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${filteredMovies.length} résultat${filteredMovies.length > 1 ? 's' : ''}',
              ),
              FilledButton.icon(
                onPressed: exporting ? null : exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF / Imprimer'),
              ),
              OutlinedButton.icon(
                onPressed: exporting ? null : exportCsv,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Exporter en CSV'),
              ),
              if (exporting)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (filteredMovies.isEmpty)
            const Text('Aucun contenu ne correspond à ces filtres.')
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                      label: SizedBox(width: 220, child: Text('Titre')),
                    ),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Année')),
                    DataColumn(label: Text('Propriétaire')),
                    DataColumn(label: Text('Support')),
                    DataColumn(label: Text('Emplacement')),
                    DataColumn(
                      label: SizedBox(width: 150, child: Text('Possession')),
                    ),
                  ],
                  rows: [
                    for (final movie in filteredMovies)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(movie.typeLabel)),
                          DataCell(Text(movie.year)),
                          DataCell(Text(movie.member)),
                          DataCell(Text(movie.formatLabel)),
                          DataCell(Text(movie.sourceName)),
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                movie.isSeries
                                    ? movie.ownershipLabel
                                    : 'Film complet',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class EmptyLibraryMessage extends StatelessWidget {
  const EmptyLibraryMessage({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onAdd,
    icon: const Icon(Icons.add),
    label: const Text('Ajouter le premier film ou la première série'),
  );
}

class LibraryFilters extends StatelessWidget {
  const LibraryFilters({
    super.key,
    required this.mediaType,
    required this.format,
    required this.genre,
    required this.age,
    required this.year,
    required this.sort,
    required this.genres,
    required this.ages,
    required this.years,
    required this.onMediaTypeChanged,
    required this.onFormatChanged,
    required this.onGenreChanged,
    required this.onAgeChanged,
    required this.onYearChanged,
    required this.onSortChanged,
  });

  final String mediaType;
  final String format;
  final String genre;
  final String age;
  final String year;
  final String sort;
  final List<String> genres;
  final List<String> ages;
  final List<String> years;
  final ValueChanged<String> onMediaTypeChanged;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onGenreChanged;
  final ValueChanged<String> onAgeChanged;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final filterWidth = constraints.maxWidth < 520
          ? constraints.maxWidth
          : 190.0;
      final filters = [
        _filter(
          label: 'Type de contenu',
          value: mediaType,
          items: const {'all': 'Tous', 'movie': 'Films', 'tv': 'Séries'},
          onChanged: onMediaTypeChanged,
        ),
        _filter(
          label: 'Type de support',
          value: format,
          items: const {
            'all': 'Tous',
            'dvd': 'DVD',
            'bluray': 'Blu-ray',
            'bluray_4k': 'Blu-ray 4K',
            'digital': 'Numérique',
            'vhs': 'VHS',
            'other': 'Autre',
          },
          onChanged: onFormatChanged,
        ),
        _filter(
          label: 'Genre',
          value: genre,
          items: {'all': 'Tous', for (final item in genres) item: item},
          onChanged: onGenreChanged,
        ),
        _filter(
          label: 'Âge conseillé',
          value: age,
          items: {
            'all': 'Tous',
            for (final item in ages) item: LibraryMovie.ageLabel(item),
          },
          onChanged: onAgeChanged,
        ),
        _filter(
          label: 'Année',
          value: year,
          items: {'all': 'Toutes', for (final item in years) item: item},
          onChanged: onYearChanged,
        ),
        _filter(
          label: 'Classer par',
          value: sort,
          items: const {
            'recent': 'Ajout récent',
            'title': 'Titre',
            'year': 'Année',
            'age': 'Âge conseillé',
          },
          onChanged: onSortChanged,
        ),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: filters
            .map((filter) => SizedBox(width: filterWidth, child: filter))
            .toList(),
      );
    },
  );

  Widget _filter({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items.entries
        .map(
          (item) => DropdownMenuItem(
            value: item.key,
            child: Text(item.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (newValue) {
      if (newValue != null) onChanged(newValue);
    },
  );
}

class MovieStrip extends StatefulWidget {
  const MovieStrip({
    super.key,
    required this.movies,
    this.canDeleteAny = false,
    this.wish = false,
    this.onDelete,
    this.onOpen,
  });
  final List<LibraryMovie> movies;
  final bool canDeleteAny;
  final bool wish;
  final Future<void> Function(LibraryMovie movie)? onDelete;
  final Future<void> Function(LibraryMovie movie)? onOpen;

  @override
  State<MovieStrip> createState() => MovieStripState();
}

class MovieStripState extends State<MovieStrip> {
  final ScrollController scrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => updateButtons());
  }

  @override
  void didUpdateWidget(covariant MovieStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => updateButtons());
  }

  @override
  void dispose() {
    scrollController
      ..removeListener(updateButtons)
      ..dispose();
    super.dispose();
  }

  void updateButtons() {
    if (!mounted || !scrollController.hasClients) return;
    final position = scrollController.position;
    final left = position.pixels > position.minScrollExtent + 2;
    final right = position.pixels < position.maxScrollExtent - 2;
    if (left != canScrollLeft || right != canScrollRight) {
      setState(() {
        canScrollLeft = left;
        canScrollRight = right;
      });
    }
  }

  Future<void> scrollBy(int direction) async {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final distance = position.viewportDimension * .82 * direction;
    final target = (position.pixels + distance).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Widget arrowButton({
    required bool left,
    required bool enabled,
    required double size,
  }) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
    elevation: enabled ? 5 : 0,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: left ? 'Films précédents' : 'Films suivants',
      onPressed: enabled ? () => scrollBy(left ? -1 : 1) : null,
      icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
      iconSize: 30,
      constraints: BoxConstraints.tightFor(width: size, height: size),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final arrowSize = mobile ? 48.0 : 52.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: mobile ? 342 : 300,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: arrowSize * .72),
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) => SizedBox(
              width: mobile ? 172 : 145,
              child: LibraryMovieCard(
                movie: widget.movies[index],
                canDeleteAny: widget.canDeleteAny,
                wish: widget.wish,
                onDelete: widget.onDelete,
                onOpen: widget.onOpen,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          child: arrowButton(
            left: true,
            enabled: canScrollLeft,
            size: arrowSize,
          ),
        ),
        Positioned(
          right: 0,
          child: arrowButton(
            left: false,
            enabled: canScrollRight,
            size: arrowSize,
          ),
        ),
      ],
    );
  }
}

class LibraryMovieCard extends StatelessWidget {
  const LibraryMovieCard({
    super.key,
    required this.movie,
    required this.wish,
    this.canDeleteAny = false,
    this.onDelete,
    this.onOpen,
  });

  final LibraryMovie movie;
  final bool wish;
  final bool canDeleteAny;
  final Future<void> Function(LibraryMovie movie)? onDelete;
  final Future<void> Function(LibraryMovie movie)? onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen == null ? null : () => onOpen!(movie),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: const Color(0xFFE2DED4),
            child: movie.posterUrl == null
                ? const Icon(Icons.movie_outlined, size: 46)
                : Image.network(
                    movie.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (!wish &&
                (canDeleteAny ||
                    movie.ownerId ==
                        Supabase.instance.client.auth.currentUser?.id))
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Retirer de la vidéothèque',
                  onPressed: onDelete == null ? null : () => onDelete!(movie),
                  icon: const Icon(Icons.delete_outline, size: 22),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${movie.year}${movie.member.isEmpty ? '' : ' · ${movie.member}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF77736B)),
        ),
        if (!wish && movie.format.isNotEmpty)
          Text(
            movie.sourceName.isEmpty
                ? movie.formatLabel
                : '${movie.formatLabel} · ${movie.sourceName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: accent),
          ),
        if (!wish && movie.isSeries)
          Text(
            movie.ownershipLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF55514A)),
          ),
      ],
    ),
  );
}

class LibraryMovie {
  const LibraryMovie({
    required this.copyId,
    required this.ownerId,
    required this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.releaseDate,
    required this.posterPath,
    required this.member,
    required this.format,
    required this.sourceName,
    required this.ownershipScope,
    required this.seasonNumbers,
    this.details,
  });

  factory LibraryMovie.fromCopy(Map<String, dynamic> row) {
    final movie = Map<String, dynamic>.from(row['movies'] as Map);
    final member = Map<String, dynamic>.from(row['household_members'] as Map);
    return LibraryMovie(
      copyId: row['id'] as String,
      ownerId: row['owner_id'] as String,
      id: movie['id'] as String,
      tmdbId: movie['tmdb_id'] as int,
      mediaType: movie['media_type'] as String? ?? 'movie',
      title: movie['title'] as String,
      overview: movie['overview'] as String? ?? '',
      releaseDate: movie['release_date'] as String?,
      posterPath: movie['poster_path'] as String?,
      member: member['display_name'] as String? ?? '',
      format: row['format'] as String? ?? '',
      sourceName: row['media_sources'] == null
          ? ''
          : (row['media_sources'] as Map)['name'] as String? ?? '',
      ownershipScope: row['ownership_scope'] as String? ?? 'movie',
      seasonNumbers: (row['season_numbers'] as List? ?? const []).cast<int>(),
    );
  }

  factory LibraryMovie.fromWish(Map<String, dynamic> row) {
    final movie = Map<String, dynamic>.from(row['movies'] as Map);
    final member = Map<String, dynamic>.from(row['household_members'] as Map);
    return LibraryMovie(
      copyId: '',
      ownerId: '',
      id: movie['id'] as String,
      tmdbId: movie['tmdb_id'] as int,
      mediaType: movie['media_type'] as String? ?? 'movie',
      title: movie['title'] as String,
      overview: movie['overview'] as String? ?? '',
      releaseDate: movie['release_date'] as String?,
      posterPath: movie['poster_path'] as String?,
      member: member['display_name'] as String? ?? '',
      format: '',
      sourceName: '',
      ownershipScope: 'movie',
      seasonNumbers: const [],
    );
  }

  final String copyId;
  final String ownerId;
  final String id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String overview;
  final String? releaseDate;
  final String? posterPath;
  final String member;
  final String format;
  final String sourceName;
  final String ownershipScope;
  final List<int> seasonNumbers;
  final TmdbMovieDetails? details;

  LibraryMovie withDetails(TmdbMovieDetails? value) => LibraryMovie(
    copyId: copyId,
    ownerId: ownerId,
    id: id,
    tmdbId: tmdbId,
    mediaType: mediaType,
    title: title,
    overview: overview,
    releaseDate: releaseDate,
    posterPath: posterPath,
    member: member,
    format: format,
    sourceName: sourceName,
    ownershipScope: ownershipScope,
    seasonNumbers: seasonNumbers,
    details: value,
  );

  String get year => releaseDate?.split('-').first ?? '';
  bool get isSeries => mediaType == 'tv';
  String get typeLabel => isSeries ? 'Série' : 'Film';
  String get tmdbKey => '$mediaType:$tmdbId';
  String get ownershipLabel => switch (ownershipScope) {
    'complete_series' => 'Série complète',
    'single_season' => 'Saison ${seasonNumbers.firstOrNull ?? '?'}',
    'selected_seasons' =>
      'Saisons ${seasonNumbers.map((number) => number.toString()).join(', ')}',
    _ => '',
  };
  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w342$posterPath';
  String? get printPosterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w780$posterPath';
  String get formatLabel => switch (format) {
    'dvd' => 'DVD',
    'bluray' => 'Blu-ray',
    'bluray_4k' => 'Blu-ray 4K',
    'digital' => 'Numérique',
    'vhs' => 'VHS',
    _ => 'Autre',
  };

  List<String> get genres => details?.genres ?? const [];
  String get ageCategory {
    final raw = details?.certification?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return 'unknown';
    if (raw == 'U' || raw == 'TP' || raw.contains('TOUS')) return 'all';
    final match = RegExp(r'\d+').firstMatch(raw);
    return match?.group(0) ?? 'unknown';
  }

  int get ageSortValue => ageValue(ageCategory);
  static int ageValue(String age) => switch (age) {
    'all' => 0,
    'unknown' => 99,
    _ => int.tryParse(age) ?? 99,
  };
  static String ageLabel(String age) => switch (age) {
    'all' => 'Tout public',
    'unknown' => 'Non renseigné',
    _ => '$age ans et +',
  };
}

class TmdbMovieDetails {
  const TmdbMovieDetails({
    required this.tmdbId,
    required this.mediaType,
    required this.overview,
    required this.backdropPath,
    required this.runtime,
    required this.voteAverage,
    required this.certification,
    required this.genres,
    required this.cast,
    required this.videos,
  });

  factory TmdbMovieDetails.fromJson(Map<String, dynamic> json) =>
      TmdbMovieDetails(
        tmdbId: json['tmdb_id'] as int,
        mediaType: json['media_type'] as String? ?? 'movie',
        overview: json['overview'] as String? ?? '',
        backdropPath: json['backdrop_path'] as String?,
        runtime: json['runtime'] as int?,
        voteAverage: (json['vote_average'] as num?)?.toDouble(),
        certification: json['certification'] as String?,
        genres: (json['genres'] as List? ?? const []).cast<String>(),
        cast: (json['cast'] as List? ?? const [])
            .map(
              (item) =>
                  TmdbActor.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        videos: (json['videos'] as List? ?? const [])
            .map(
              (item) =>
                  TmdbVideo.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );

  final int tmdbId;
  final String mediaType;
  final String overview;
  final String? backdropPath;
  final int? runtime;
  final double? voteAverage;
  final String? certification;
  final List<String> genres;
  final List<TmdbActor> cast;
  final List<TmdbVideo> videos;
  String get tmdbKey => '$mediaType:$tmdbId';

  String? get backdropUrl => backdropPath == null
      ? null
      : 'https://image.tmdb.org/t/p/w1280$backdropPath';
}

class TmdbActor {
  const TmdbActor({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  factory TmdbActor.fromJson(Map<String, dynamic> json) => TmdbActor(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'Interprète',
    character: json['character'] as String? ?? '',
    profilePath: json['profile_path'] as String?,
  );

  final int id;
  final String name;
  final String character;
  final String? profilePath;
  String? get profileUrl => profilePath == null
      ? null
      : 'https://image.tmdb.org/t/p/w185$profilePath';
}

class TmdbVideo {
  const TmdbVideo({
    required this.name,
    required this.key,
    required this.site,
    required this.type,
    required this.official,
  });

  factory TmdbVideo.fromJson(Map<String, dynamic> json) => TmdbVideo(
    name: json['name'] as String? ?? 'Vidéo',
    key: json['key'] as String,
    site: json['site'] as String,
    type: json['type'] as String? ?? 'Vidéo',
    official: json['official'] as bool? ?? false,
  );

  final String name;
  final String key;
  final String site;
  final String type;
  final bool official;
  Uri get uri => site == 'Vimeo'
      ? Uri.parse('https://vimeo.com/$key')
      : Uri.parse('https://www.youtube.com/watch?v=$key');
}

class MoviePresentation extends StatelessWidget {
  const MoviePresentation({super.key, required this.movie});
  final LibraryMovie movie;

  Future<void> openVideo(BuildContext context, TmdbVideo video) async {
    if (!await launchUrl(video.uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir cette vidéo.')),
      );
    }
  }

  void showActor(BuildContext context, TmdbActor actor) {
    showDialog<void>(
      context: context,
      builder: (_) => ActorDetailDialog(actor: actor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = movie.details;
    final overview = details?.overview.isNotEmpty == true
        ? details!.overview
        : movie.overview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 320),
          decoration: BoxDecoration(
            color: ink,
            image: details?.backdropUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(details!.backdropUrl!),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      Color(0x99171715),
                      BlendMode.darken,
                    ),
                  ),
          ),
          padding: const EdgeInsets.all(26),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final poster = SizedBox(
                width: compact ? 105 : 150,
                height: compact ? 158 : 225,
                child: movie.posterUrl == null
                    ? const ColoredBox(
                        color: Color(0xFFE2DED4),
                        child: Icon(Icons.movie_outlined, size: 52),
                      )
                    : Image.network(movie.posterUrl!, fit: BoxFit.cover),
              );
              final information = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    movie.title,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: compact ? 31 : 45,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (movie.year.isNotEmpty) _badge(movie.year),
                      if (details?.runtime != null)
                        _badge('${details!.runtime} min'),
                      if (movie.ageCategory != 'unknown')
                        _badge(LibraryMovie.ageLabel(movie.ageCategory)),
                      if (details?.voteAverage != null)
                        _badge(
                          '★ ${details!.voteAverage!.toStringAsFixed(1)}/10',
                        ),
                      ...movie.genres.map(_badge),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (movie.member.isNotEmpty)
                    Text(
                      'Dans la collection de ${movie.member}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (movie.format.isNotEmpty)
                    Text(
                      movie.sourceName.isEmpty
                          ? movie.formatLabel
                          : '${movie.formatLabel} · ${movie.sourceName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (movie.isSeries && movie.ownershipLabel.isNotEmpty)
                    Text(
                      movie.ownershipLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(height: 18),
                        information,
                      ],
                    )
                  : Row(
                      children: [
                        poster,
                        const SizedBox(width: 28),
                        Expanded(child: information),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Synopsis',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
        ),
        const SizedBox(height: 9),
        Text(
          overview.isEmpty
              ? 'Aucun synopsis disponible en français.'
              : overview,
          style: const TextStyle(fontSize: 16, height: 1.55),
        ),
        if (details?.cast.isNotEmpty == true) ...[
          const SizedBox(height: 38),
          const Text(
            'Distribution',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 225,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: details!.cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final actor = details.cast[index];
                return SizedBox(
                  width: 120,
                  child: InkWell(
                    onTap: () => showActor(context, actor),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 150,
                          child: actor.profileUrl == null
                              ? const ColoredBox(
                                  color: Color(0xFFE2DED4),
                                  child: Icon(Icons.person_outline),
                                )
                              : Image.network(
                                  actor.profileUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          actor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          actor.character,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (details?.videos.isNotEmpty == true) ...[
          const SizedBox(height: 38),
          const Text(
            'Vidéos et bandes-annonces',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: details!.videos
                .map(
                  (video) => OutlinedButton.icon(
                    onPressed: () => openVideo(context, video),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                      '${video.type} · ${video.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black54,
      border: Border.all(color: Colors.white38),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

class ActorDetailDialog extends StatefulWidget {
  const ActorDetailDialog({super.key, required this.actor});
  final TmdbActor actor;

  @override
  State<ActorDetailDialog> createState() => _ActorDetailDialogState();
}

class _ActorDetailDialogState extends State<ActorDetailDialog> {
  Map<String, dynamic>? details;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-person',
        body: {'person_id': widget.actor.id},
      );
      if (!mounted) return;
      setState(() {
        details = Map<String, dynamic>.from(response.data as Map);
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = details;
    final profilePath = data?['profile_path'] as String?;
    final profileUrl = profilePath == null
        ? widget.actor.profileUrl
        : 'https://image.tmdb.org/t/p/w342$profilePath';
    final knownFor = data?['known_for'] as List? ?? const [];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: loading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Wrap(
                    spacing: 22,
                    runSpacing: 18,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 210,
                        child: profileUrl == null
                            ? const ColoredBox(
                                color: Color(0xFFE2DED4),
                                child: Icon(Icons.person_outline, size: 64),
                              )
                            : Image.network(profileUrl, fit: BoxFit.cover),
                      ),
                      SizedBox(
                        width: 390,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.actor.name,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 32,
                              ),
                            ),
                            if (widget.actor.character.isNotEmpty)
                              Text('Dans ce film : ${widget.actor.character}'),
                            if (data?['birthday'] != null)
                              Text('Naissance : ${data!['birthday']}'),
                            if (data?['place_of_birth'] != null)
                              Text('Lieu : ${data!['place_of_birth']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Biographie',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (data?['biography'] as String?)?.isNotEmpty == true
                        ? data!['biography'] as String
                        : 'Aucune biographie disponible en français.',
                    style: const TextStyle(height: 1.5),
                  ),
                  if (knownFor.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'Films connus',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: knownFor.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final movie = Map<String, dynamic>.from(
                            knownFor[index] as Map,
                          );
                          final poster = movie['poster_path'] as String?;
                          return SizedBox(
                            width: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 140,
                                  child: poster == null
                                      ? const ColoredBox(
                                          color: Color(0xFFE2DED4),
                                          child: Icon(Icons.movie_outlined),
                                        )
                                      : Image.network(
                                          'https://image.tmdb.org/t/p/w185$poster',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Text(
                                  movie['title'] as String? ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class DvdCoverPdf {
  static const double backWidthMm = 129;
  static const double spineWidthMm = 15;
  static const double frontWidthMm = 129;
  static const double coverHeightMm = 183;

  static Future<Uint8List> build(
    LibraryMovie movie, {
    pw.ImageProvider? poster,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
    );
    final document = pw.Document(
      title: 'Jaquette DVD - ${movie.title}',
      author: 'FamilyFlix',
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    const pageFormat = PdfPageFormat.a4;
    final mm = PdfPageFormat.mm;
    final coverWidth = (backWidthMm + spineWidthMm + frontWidthMm) * mm;
    final coverHeight = coverHeightMm * mm;
    final overview = movie.details?.overview.isNotEmpty == true
        ? movie.details!.overview
        : movie.overview;
    final metadata = [
      movie.typeLabel,
      if (movie.year.isNotEmpty) movie.year,
      if (movie.details?.runtime != null) '${movie.details!.runtime} min',
      ...movie.genres.take(3),
    ].join(' • ');

    document.addPage(
      pw.Page(
        pageFormat: pageFormat.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            pw.Center(
              child: pw.Container(
                width: coverWidth,
                height: coverHeight,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#171715'),
                    width: .7,
                  ),
                ),
                child: pw.Row(
                  children: [
                    _backPanel(
                      movie,
                      overview: overview,
                      metadata: metadata,
                      width: backWidthMm * mm,
                    ),
                    _spine(movie, width: spineWidthMm * mm),
                    _frontPanel(
                      movie,
                      poster: poster,
                      width: frontWidthMm * mm,
                    ),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 0,
              right: 0,
              bottom: 3.5 * mm,
              child: pw.Text(
                'Imprimer en taille réelle (100 %) - découper le contour - plier aux deux lignes de la tranche',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColor.fromHex('#5D5A53'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _backPanel(
    LibraryMovie movie, {
    required String overview,
    required String metadata,
    required double width,
  }) => pw.Container(
    width: width,
    height: double.infinity,
    padding: const pw.EdgeInsets.all(22),
    color: PdfColor.fromHex('#F3F0E8'),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FAMILYFLIX',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#E84E2C'),
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          movie.title,
          maxLines: 3,
          style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
        ),
        if (metadata.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          pw.Text(
            metadata,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#5D5A53'),
            ),
          ),
        ],
        pw.SizedBox(height: 20),
        pw.Container(width: 28, height: 2, color: PdfColor.fromHex('#E84E2C')),
        pw.SizedBox(height: 14),
        pw.Text(
          'SYNOPSIS',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 7),
        pw.Text(
          overview.isEmpty
              ? 'Aucun synopsis disponible pour ce contenu.'
              : overview,
          maxLines: 18,
          style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2.5),
        ),
        pw.Spacer(),
        pw.Text(
          [
            if (movie.member.isNotEmpty) 'Collection de ${movie.member}',
            if (movie.formatLabel.isNotEmpty) movie.formatLabel,
            if (movie.sourceName.isNotEmpty) movie.sourceName,
          ].join(' • '),
          style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#5D5A53')),
        ),
      ],
    ),
  );

  static pw.Widget _spine(LibraryMovie movie, {required double width}) =>
      pw.Container(
        width: width,
        height: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#171715'),
          border: pw.Border.symmetric(
            vertical: pw.BorderSide(
              color: PdfColor.fromHex('#E84E2C'),
              width: .7,
            ),
          ),
        ),
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: math.pi / 2,
            child: pw.SizedBox(
              width: coverHeightMm * PdfPageFormat.mm - 36,
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.Text(
                  movie.title.toUpperCase(),
                  maxLines: 1,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  static pw.Widget _frontPanel(
    LibraryMovie movie, {
    required pw.ImageProvider? poster,
    required double width,
  }) => pw.Container(
    width: width,
    height: double.infinity,
    color: PdfColor.fromHex('#285574'),
    child: pw.Stack(
      children: [
        if (poster != null)
          pw.Positioned.fill(child: pw.Image(poster, fit: pw.BoxFit.cover))
        else
          pw.Center(
            child: pw.Text(
              'FAMILYFLIX',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: pw.Container(
            color: const PdfColor(0, 0, 0, .82),
            padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  movie.title,
                  maxLines: 3,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (movie.year.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    movie.year,
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.household,
    required this.movie,
  });

  final HouseholdSummary household;
  final LibraryMovie movie;

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final commentController = TextEditingController();
  List<MovieReview> reviews = const [];
  int rating = 0;
  bool favorite = false;
  bool loading = true;
  bool saving = false;
  bool printingCover = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('movie_reviews')
          .select(
            'user_id, rating, comment, is_favorite, updated_at, '
            'household_members!movie_reviews_member_fkey(display_name)',
          )
          .eq('household_id', widget.household.id)
          .eq('movie_id', widget.movie.id)
          .order('updated_at', ascending: false);
      final loaded = rows
          .map((row) => MovieReview.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final userId = client.auth.currentUser!.id;
      for (final review in loaded) {
        if (review.userId == userId) {
          rating = review.rating ?? 0;
          favorite = review.favorite;
          commentController.text = review.comment;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        reviews = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les avis.';
        loading = false;
      });
    }
  }

  Future<void> saveReview() async {
    final comment = commentController.text.trim();
    if (rating == 0 && comment.isEmpty && !favorite) {
      setState(() => error = 'Ajoutez une note, un avis ou un coup de cœur.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      await client.from('movie_reviews').upsert({
        'household_id': widget.household.id,
        'user_id': client.auth.currentUser!.id,
        'movie_id': widget.movie.id,
        'rating': rating == 0 ? null : rating,
        'comment': comment.isEmpty ? null : comment,
        'is_favorite': favorite,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'household_id,user_id,movie_id');
      if (!mounted) return;
      setState(() => saving = false);
      await load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible d’enregistrer votre avis.';
        saving = false;
      });
    }
  }

  Future<void> deleteMyReview() async {
    final client = Supabase.instance.client;
    await client
        .from('movie_reviews')
        .delete()
        .eq('household_id', widget.household.id)
        .eq('movie_id', widget.movie.id)
        .eq('user_id', client.auth.currentUser!.id);
    rating = 0;
    favorite = false;
    commentController.clear();
    await load();
  }

  Future<void> printDvdCover() async {
    setState(() => printingCover = true);
    try {
      pw.ImageProvider? poster;
      if (widget.movie.printPosterUrl != null) {
        try {
          poster = await networkImage(widget.movie.printPosterUrl!);
        } catch (_) {
          // Une jaquette sans affiche reste imprimable si TMDB est indisponible.
        }
      }
      final coverPoster = poster;
      await Printing.layoutPdf(
        name: 'jaquette-dvd-${widget.movie.title}.pdf',
        onLayout: (_) => DvdCoverPdf.build(widget.movie, poster: coverPoster),
      );
    } finally {
      if (mounted) setState(() => printingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.movie.title),
      backgroundColor: Theme.of(context).colorScheme.surface,
    ),
    body: PageWidth(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: printingCover ? null : printDvdCover,
                    icon: printingCover
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      printingCover
                          ? 'Préparation de la jaquette…'
                          : 'Imprimer la jaquette DVD',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                MoviePresentation(movie: widget.movie),
                const Divider(height: 64),
                const Text(
                  'Votre avis',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 26),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 2,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value sur 5',
                      onPressed: () => setState(() => rating = value),
                      icon: Icon(
                        value <= rating ? Icons.star : Icons.star_border,
                        color: accent,
                      ),
                    );
                  }),
                ),
                CheckboxListTile(
                  value: favorite,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      setState(() => favorite = value ?? false),
                  title: const Text('Coup de cœur'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                TextField(
                  controller: commentController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1500,
                  decoration: const InputDecoration(
                    labelText: 'Votre commentaire sans spoiler',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF8B2F1D)),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton(
                      onPressed: saving ? null : saveReview,
                      child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
                    ),
                    if (reviews.any(
                      (review) =>
                          review.userId ==
                          Supabase.instance.client.auth.currentUser!.id,
                    ))
                      TextButton(
                        onPressed: deleteMyReview,
                        child: const Text('Supprimer mon avis'),
                      ),
                  ],
                ),
                const SizedBox(height: 38),
                const Text(
                  'Avis de la famille',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 26),
                ),
                const SizedBox(height: 10),
                if (reviews.isEmpty)
                  const Text('Personne n’a encore donné son avis.')
                else
                  ...reviews.map(
                    (review) => Card(
                      child: ListTile(
                        title: Text(
                          '${review.displayName}${review.favorite ? ' · ❤️ Coup de cœur' : ''}',
                        ),
                        subtitle: Text(
                          '${review.rating == null ? '' : '${'★' * review.rating!}  '}${review.comment}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class MovieReview {
  const MovieReview({
    required this.userId,
    required this.displayName,
    required this.rating,
    required this.comment,
    required this.favorite,
  });

  factory MovieReview.fromJson(Map<String, dynamic> json) {
    final member = Map<String, dynamic>.from(json['household_members'] as Map);
    return MovieReview(
      userId: json['user_id'] as String,
      displayName: member['display_name'] as String? ?? 'Membre',
      rating: json['rating'] as int?,
      comment: json['comment'] as String? ?? '',
      favorite: json['is_favorite'] as bool? ?? false,
    );
  }

  final String userId;
  final String displayName;
  final int? rating;
  final String comment;
  final bool favorite;
}

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, required this.number});
  final MoviePreview movie;
  final int number;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Poster(color: movie.color, number: number),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  movie.year,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF77736B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x33171715)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              movie.owner,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ],
  );
}

class Poster extends StatelessWidget {
  const Poster({super.key, required this.color, required this.number});
  final Color color;
  final int number;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: CustomPaint(
      painter: PosterPainter(color),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 48,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Text(
              'FAMILYFLIX\nCOLLECTION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PosterPainter extends CustomPainter {
  const PosterPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .85, size.height * .45),
        width: size.width * .75,
        height: size.width * .75,
      ),
      line,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .45, size.height * 1.03),
        width: size.width * 1.55,
        height: size.height * .48,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant PosterPainter oldDelegate) =>
      oldDelegate.color != color;
}

class AddMovieCard extends StatelessWidget {
  const AddMovieCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF99958B)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ajouter votre premier film ou votre première série',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Georgia', fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recherche automatique sur Internet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF77736B)),
          ),
        ],
      ),
    ),
  );
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.withLine = false});
  final String text;
  final bool withLine;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (withLine) ...[
        Container(width: 32, height: 2, color: accent),
        const SizedBox(width: 10),
      ],
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            color: accent,
            fontSize: 11,
            letterSpacing: 2.1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class FreePromise extends StatelessWidget {
  const FreePromise({super.key});

  void openLegalNotices(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const LegalNoticesPage()));
  }

  void openProjectStory(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ProjectStoryPage()));
  }

  @override
  Widget build(BuildContext context) => PageWidth(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => openProjectStory(context),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Origine du projet'),
            ),
            TextButton.icon(
              onPressed: () => openLegalNotices(context),
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('Mentions légales et API'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProjectStoryPage extends StatelessWidget {
  const ProjectStoryPage({super.key});

  Future<void> _openRepository(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://github.com/gatounet/FamilyFlix'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir GitHub.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Origine du projet')),
    body: PageWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 30),
        children: [
          const Kicker('UNE IDÉE FAMILIALE', withLine: true),
          const SizedBox(height: 18),
          const Text(
            'Savoir ce que l’on possède.\nChoisir quoi regarder.\nLe faire ensemble.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 38,
              height: 1.08,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'FamilyFlix est né pour répondre à une question toute simple dans une famille : « Qui possède ce film, où se trouve-t-il, et qu’est-ce qu’on regarde ce soir ? »',
            style: TextStyle(fontSize: 18, height: 1.6),
          ),
          const SizedBox(height: 34),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StoryCard(
                icon: Icons.video_library_outlined,
                number: '01',
                title: 'Rassembler',
                text:
                    'Une collection commune pour les films et séries stockés sur DVD, Blu-ray, NAS, box ou tout autre support.',
              ),
              _StoryCard(
                icon: Icons.groups_outlined,
                number: '02',
                title: 'Partager',
                text:
                    'Chaque membre garde ses exemplaires tout en participant aux souhaits, avis et recommandations de la famille.',
              ),
              _StoryCard(
                icon: Icons.weekend_outlined,
                number: '03',
                title: 'Choisir',
                text:
                    'Des informations TMDB et des filtres simples pour trouver rapidement le bon programme pour tout le monde.',
              ),
            ],
          ),
          const SizedBox(height: 34),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_outline, color: accent, size: 34),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Une contrainte fondatrice : 0 €',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Le projet privilégie les solutions gratuites et ouvertes afin de rester accessible à une famille, sans abonnement ni publicité.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openRepository(context),
              icon: const Icon(Icons.code),
              label: const Text('Découvrir le projet sur GitHub'),
            ),
          ),
          const SizedBox(height: 34),
        ],
      ),
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.icon,
    required this.number,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accent, size: 34),
                Text(
                  number,
                  style: const TextStyle(
                    color: accent,
                    fontFamily: 'Georgia',
                    fontSize: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    ),
  );
}

class LegalNoticesPage extends StatelessWidget {
  const LegalNoticesPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mentions légales et services utilisés')),
    body: PageWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          const _LegalSection(
            title: 'À propos de FamilyFlix',
            text:
                'FamilyFlix est une application familiale, gratuite et sans publicité permettant de gérer une collection privée de films et de séries. Elle ne fournit, ne diffuse et n’héberge aucun film, épisode ou bande-annonce.',
          ),
          const _LegalSection(
            title: 'Données personnelles',
            text:
                'Les informations de compte, familles, collections, souhaits et avis sont enregistrées dans Supabase. Elles servent uniquement au fonctionnement de la vidéothèque familiale. Les règles d’accès de la base limitent leur consultation aux membres autorisés de la famille. Ne renseignez pas d’informations sensibles dans les avis ou les notes.',
          ),
          const _LegalSection(
            title: 'TMDB — métadonnées cinéma et télévision',
            text:
                'Les titres, affiches, synopsis, distributions, classifications, notes et informations associées proviennent de The Movie Database (TMDB). FamilyFlix utilise ces données uniquement pour identifier et présenter les œuvres dans la collection familiale. Les informations peuvent être incomplètes ou comporter des erreurs.\n\nThis product uses the TMDB API but is not endorsed or certified by TMDB.',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _open(context, 'https://www.themoviedb.org/'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Site de TMDB'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _open(context, 'https://www.themoviedb.org/terms-of-use'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Conditions de TMDB'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _LegalSection(
            title: 'Autres services et API',
            text:
                'Supabase fournit l’authentification, la base de données et les fonctions techniques qui interrogent TMDB. GitHub Pages héberge l’application web. Les liens vers les bandes-annonces peuvent ouvrir YouTube ou Vimeo dans une application ou un site externe, soumis à leurs propres conditions et politiques de confidentialité.',
          ),
          const _LegalSection(
            title: 'Responsabilité et usage',
            text:
                'FamilyFlix est destiné à un usage privé et familial. Chaque utilisateur reste responsable des informations qu’il ajoute et du respect des droits applicables aux supports qu’il possède. Les données affichées depuis des services tiers restent la propriété de leurs titulaires respectifs.',
          ),
          const _LegalSection(
            title: 'Projet et hébergement',
            text:
                'Le code source de FamilyFlix est publié sur GitHub. L’application est proposée sans garantie de disponibilité permanente. Ces mentions pourront évoluer si de nouveaux services sont ajoutés.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () =>
                  _open(context, 'https://github.com/gatounet/FamilyFlix'),
              icon: const Icon(Icons.code),
              label: const Text('Voir le projet sur GitHub'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 16, height: 1.55)),
      ],
    ),
  );
}

class MoviePreview {
  const MoviePreview(this.title, this.year, this.owner, this.color);
  final String title;
  final String year;
  final String owner;
  final Color color;
}

class HouseholdSummary {
  const HouseholdSummary({
    required this.id,
    required this.name,
    required this.displayName,
    required this.role,
    required this.filmCount,
  });
  final String id;
  final String name;
  final String displayName;
  final String role;
  final int filmCount;
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    role: json['role'] as String,
  );

  final String userId;
  final String displayName;
  final String role;

  String get roleLabel => switch (role) {
    'owner' => 'Créateur de la famille',
    'admin' => 'Administrateur',
    _ => 'Membre',
  };
}
