import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const paper = Color(0xFFF3F0E8);
const ink = Color(0xFF171715);
const accent = Color(0xFFE84E2C);
bool supabaseReady = false;

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
  runApp(const FamilyFlixApp());
}

class FamilyFlixApp extends StatelessWidget {
  const FamilyFlixApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FamilyFlix',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, surface: paper),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ink, height: 1.55),
        bodyMedium: TextStyle(color: Color(0xFF5D5A53)),
      ),
    ),
    home: const AuthGate(),
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .42),
                border: Border.all(color: const Color(0x2E171715)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Logo()),
                  const SizedBox(height: 38),
                  Text(
                    createAccount
                        ? 'Rejoindre la famille'
                        : 'Bon retour parmi nous',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 34,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    createAccount
                        ? 'Créez votre accès privé à la vidéothèque.'
                        : 'Connectez-vous pour retrouver vos films.',
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
                      helperText: createAccount ? '8 caractères minimum' : null,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
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
                            createAccount ? 'Créer mon compte' : 'Se connecter',
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() {
                            createAccount = !createAccount;
                            message = null;
                          }),
                    style: TextButton.styleFrom(foregroundColor: ink),
                    child: Text(
                      createAccount
                          ? 'J’ai déjà un compte'
                          : 'Créer un compte familial',
                    ),
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
      backgroundColor: paper,
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
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 34,
                    color: ink,
                  ),
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
            ),
          ),
          SliverToBoxAdapter(
            child: HeroSection(
              onAdd: () => openMovieSearch(context),
              onManageSources: () => openMediaSources(context),
              onManageFamily:
                  household?.role == 'owner' || household?.role == 'admin'
                  ? () => openFamilyAccess(context)
                  : null,
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
  List<TmdbMovie> results = const [];
  bool loading = false;
  String? error;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = searchController.text.trim();
    if (query.length < 2) {
      setState(() => error = 'Saisissez au moins deux caractères.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tmdb-search',
        body: {'query': query},
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
      title: const Text('Trouver un film'),
      backgroundColor: paper,
    ),
    body: PageWidth(
      child: Column(
        children: [
          const SizedBox(height: 22),
          TextField(
            controller: searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              labelText: 'Titre du film',
              hintText: 'Ex. Le Seigneur des anneaux',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: loading ? null : search,
                icon: const Icon(Icons.search),
              ),
            ),
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
                      'Recherchez un film pour l’ajouter à votre\ncollection ou à vos souhaits.',
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
                        trailing: const Icon(Icons.chevron_right),
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
  String? mediaSourceId;
  List<MediaSource> mediaSources = const [];
  bool loadingSources = true;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMediaSources();
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final movieRow = await client
          .from('movies')
          .upsert(widget.movie.toDatabase(), onConflict: 'tmdb_id')
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
        error = 'Impossible d’enregistrer ce film pour le moment.';
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
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              color: ink,
            ),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Supports de la famille'),
      backgroundColor: paper,
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

class TmdbMovie {
  const TmdbMovie({
    required this.tmdbId,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.releaseDate,
    required this.posterPath,
  });

  factory TmdbMovie.fromJson(Map<String, dynamic> json) => TmdbMovie(
    tmdbId: json['tmdb_id'] as int,
    title: json['title'] as String? ?? 'Sans titre',
    originalTitle: json['original_title'] as String?,
    overview: json['overview'] as String? ?? '',
    releaseDate: json['release_date'] as String?,
    posterPath: json['poster_path'] as String?,
  );

  final int tmdbId;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? releaseDate;
  final String? posterPath;

  String get year => releaseDate?.split('-').first ?? '';
  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w185$posterPath';

  Map<String, dynamic> toDatabase() => {
    'tmdb_id': tmdbId,
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
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: child,
      ),
    ),
  );
}

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.onLogin,
    this.authenticated = false,
    this.memberName,
    this.familyName,
    this.filmCount = 0,
  });
  final VoidCallback onLogin;
  final bool authenticated;
  final String? memberName;
  final String? familyName;
  final int filmCount;

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
          if (MediaQuery.sizeOf(context).width > 520)
            TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(foregroundColor: ink),
              child: Text(
                authenticated ? 'Se déconnecter' : 'Se connecter',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          const SizedBox(width: 12),
          if (memberName != null &&
              MediaQuery.sizeOf(context).width <= 720) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                memberName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if ((memberName != null || familyName != null) &&
              MediaQuery.sizeOf(context).width > 720) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  memberName ?? familyName!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  [
                    ?familyName,
                    '$filmCount film${filmCount > 1 ? 's' : ''}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF77736B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          FamilyAvatar(filmCount: filmCount, size: 42),
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
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Family',
          style: TextStyle(color: ink),
        ),
        TextSpan(
          text: 'Flix',
          style: TextStyle(color: accent),
        ),
      ],
    ),
    style: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.4,
    ),
  );
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.onAdd,
    required this.onManageSources,
    this.onManageFamily,
  });
  final VoidCallback onAdd;
  final VoidCallback onManageSources;
  final VoidCallback? onManageFamily;

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
                color: ink,
                fontFamily: 'Georgia',
                fontSize: mobile ? 52 : 88,
                height: .94,
                letterSpacing: mobile ? -2 : -4,
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
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Ajouter un film'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: onManageSources,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: const BorderSide(color: ink),
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
                if (onManageFamily != null)
                  OutlinedButton.icon(
                    onPressed: onManageFamily,
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Gérer la famille'),
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
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 39,
                    color: ink,
                  ),
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
  String formatFilter = 'all';
  String genreFilter = 'all';
  String ageFilter = 'all';
  String sortOrder = 'recent';

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
              'id, owner_id, format, movies!copies_movie_id_fkey(id, tmdb_id, title, overview, release_date, poster_path), '
              'household_members!copies_household_id_owner_id_fkey(display_name), '
              'media_sources!copies_media_source_scope_fkey(name)',
            )
            .eq('household_id', widget.household.id)
            .order('created_at', ascending: false),
        client
            .from('watchlists')
            .select(
              'movies!watchlists_movie_id_fkey(id, tmdb_id, title, overview, release_date, poster_path), '
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
      final details = await loadTmdbDetails([
        ...parsedCopies.map((movie) => movie.tmdbId),
        ...parsedWishes.map((movie) => movie.tmdbId),
      ]);
      if (!mounted) return;
      setState(() {
        copies = parsedCopies
            .map((movie) => movie.withDetails(details[movie.tmdbId]))
            .toList();
        wishes = parsedWishes
            .map((movie) => movie.withDetails(details[movie.tmdbId]))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Impossible de charger les films de la famille.';
        loading = false;
      });
    }
  }

  Future<Map<int, TmdbMovieDetails>> loadTmdbDetails(List<int> ids) async {
    final uniqueIds = ids.where((id) => id > 0).toSet().toList();
    final details = <int, TmdbMovieDetails>{};
    try {
      for (var start = 0; start < uniqueIds.length; start += 50) {
        final end = (start + 50).clamp(0, uniqueIds.length);
        final response = await Supabase.instance.client.functions.invoke(
          'tmdb-details',
          body: {'movie_ids': uniqueIds.sublist(start, end)},
        );
        final payload = Map<String, dynamic>.from(response.data as Map);
        for (final item in payload['movies'] as List? ?? const []) {
          final detail = TmdbMovieDetails.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          details[detail.tmdbId] = detail;
        }
      }
    } catch (_) {
      // La vidéothèque locale reste utilisable si TMDB est momentanément absent.
    }
    return details;
  }

  List<LibraryMovie> get filteredCopies {
    final result = copies.where((movie) {
      final formatMatches =
          formatFilter == 'all' || movie.format == formatFilter;
      final genreMatches =
          genreFilter == 'all' || movie.genres.contains(genreFilter);
      final ageMatches = ageFilter == 'all' || movie.ageCategory == ageFilter;
      return formatMatches && genreMatches && ageMatches;
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

  Future<void> deleteCopy(LibraryMovie movie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce film ?'),
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
        const SnackBar(content: Text('Impossible de retirer ce film.')),
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
                    'Les films que vous possédez',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 36,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (copies.isEmpty)
                    EmptyLibraryMessage(onAdd: widget.onAdd)
                  else ...[
                    LibraryFilters(
                      format: formatFilter,
                      genre: genreFilter,
                      age: ageFilter,
                      sort: sortOrder,
                      genres: availableGenres,
                      ages: availableAges,
                      onFormatChanged: (value) =>
                          setState(() => formatFilter = value),
                      onGenreChanged: (value) =>
                          setState(() => genreFilter = value),
                      onAgeChanged: (value) =>
                          setState(() => ageFilter = value),
                      onSortChanged: (value) =>
                          setState(() => sortOrder = value),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${filteredCopies.length} film${filteredCopies.length > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 10),
                    if (filteredCopies.isEmpty)
                      const Text('Aucun film ne correspond à ces filtres.')
                    else
                      MovieStrip(
                        movies: filteredCopies,
                        onDelete: deleteCopy,
                        onOpen: openMovie,
                      ),
                  ],
                  const SizedBox(height: 52),
                  const Kicker('IDÉES DES MEMBRES'),
                  const SizedBox(height: 8),
                  const Text(
                    'Les souhaits de la famille',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 36,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (wishes.isEmpty)
                    const Text(
                      'Aucun souhait pour le moment. Utilisez “Ajouter un film” pour proposer une idée.',
                    )
                  else
                    MovieStrip(movies: wishes, wish: true, onOpen: openMovie),
                ],
              ),
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
    label: const Text('Ajouter le premier film'),
  );
}

class LibraryFilters extends StatelessWidget {
  const LibraryFilters({
    super.key,
    required this.format,
    required this.genre,
    required this.age,
    required this.sort,
    required this.genres,
    required this.ages,
    required this.onFormatChanged,
    required this.onGenreChanged,
    required this.onAgeChanged,
    required this.onSortChanged,
  });

  final String format;
  final String genre;
  final String age;
  final String sort;
  final List<String> genres;
  final List<String> ages;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onGenreChanged;
  final ValueChanged<String> onAgeChanged;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
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
    ],
  );

  Widget _filter({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
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
    ),
  );
}

class MovieStrip extends StatelessWidget {
  const MovieStrip({
    super.key,
    required this.movies,
    this.wish = false,
    this.onDelete,
    this.onOpen,
  });
  final List<LibraryMovie> movies;
  final bool wish;
  final Future<void> Function(LibraryMovie movie)? onDelete;
  final Future<void> Function(LibraryMovie movie)? onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: movies.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (context, index) => SizedBox(
        width: 145,
        child: LibraryMovieCard(
          movie: movies[index],
          wish: wish,
          onDelete: onDelete,
          onOpen: onOpen,
        ),
      ),
    ),
  );
}

class LibraryMovieCard extends StatelessWidget {
  const LibraryMovieCard({
    super.key,
    required this.movie,
    required this.wish,
    this.onDelete,
    this.onOpen,
  });

  final LibraryMovie movie;
  final bool wish;
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
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
            ),
            if (!wish &&
                movie.ownerId == Supabase.instance.client.auth.currentUser?.id)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Retirer de la vidéothèque',
                  onPressed: onDelete == null ? null : () => onDelete!(movie),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${movie.year}${movie.member.isEmpty ? '' : ' · ${movie.member}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF77736B)),
        ),
        if (!wish && movie.format.isNotEmpty)
          Text(
            movie.sourceName.isEmpty
                ? movie.formatLabel
                : '${movie.formatLabel} · ${movie.sourceName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: accent),
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
    required this.title,
    required this.overview,
    required this.releaseDate,
    required this.posterPath,
    required this.member,
    required this.format,
    required this.sourceName,
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
      title: movie['title'] as String,
      overview: movie['overview'] as String? ?? '',
      releaseDate: movie['release_date'] as String?,
      posterPath: movie['poster_path'] as String?,
      member: member['display_name'] as String? ?? '',
      format: row['format'] as String? ?? '',
      sourceName: row['media_sources'] == null
          ? ''
          : (row['media_sources'] as Map)['name'] as String? ?? '',
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
      title: movie['title'] as String,
      overview: movie['overview'] as String? ?? '',
      releaseDate: movie['release_date'] as String?,
      posterPath: movie['poster_path'] as String?,
      member: member['display_name'] as String? ?? '',
      format: '',
      sourceName: '',
    );
  }

  final String copyId;
  final String ownerId;
  final String id;
  final int tmdbId;
  final String title;
  final String overview;
  final String? releaseDate;
  final String? posterPath;
  final String member;
  final String format;
  final String sourceName;
  final TmdbMovieDetails? details;

  LibraryMovie withDetails(TmdbMovieDetails? value) => LibraryMovie(
    copyId: copyId,
    ownerId: ownerId,
    id: id,
    tmdbId: tmdbId,
    title: title,
    overview: overview,
    releaseDate: releaseDate,
    posterPath: posterPath,
    member: member,
    format: format,
    sourceName: sourceName,
    details: value,
  );

  String get year => releaseDate?.split('-').first ?? '';
  String? get posterUrl =>
      posterPath == null ? null : 'https://image.tmdb.org/t/p/w342$posterPath';
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
  final String overview;
  final String? backdropPath;
  final int? runtime;
  final double? voteAverage;
  final String? certification;
  final List<String> genres;
  final List<TmdbActor> cast;
  final List<TmdbVideo> videos;

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
          style: TextStyle(fontFamily: 'Georgia', fontSize: 28, color: ink),
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
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28, color: ink),
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
            style: TextStyle(fontFamily: 'Georgia', fontSize: 28, color: ink),
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
                                color: ink,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.movie.title), backgroundColor: paper),
    body: PageWidth(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                MoviePresentation(movie: widget.movie),
                const Divider(height: 64),
                const Text(
                  'Votre avis',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 26,
                    color: ink,
                  ),
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
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 26,
                    color: ink,
                  ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
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
              border: Border.all(color: ink),
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ajouter votre premier film',
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

  @override
  Widget build(BuildContext context) => PageWidth(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 40,
        runSpacing: 24,
        children: [
          const Text(
            'CONÇU POUR RESTER GRATUIT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '0 €',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  color: accent,
                  fontSize: 58,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                'Pas d’abonnement.\nPas de publicité.\nVos données restent à vous.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
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
