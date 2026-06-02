import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../widgets/common_widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});
  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  String _subject = 'Physics';
  final _subjects = ['Physics', 'Maths', 'Chemistry', 'English', 'CS'];

  // ── Material data with content for PDF generation ─────────────────────────
  final _materials = {
    'Physics': [
      {
        'title': 'Thermodynamics Notes',
        'pages': 24,
        'isNew': true,
        'content': [
          (
            'Introduction to Thermodynamics',
            'Thermodynamics is the branch of physics that deals with heat, work, and temperature, and their relation to energy, entropy, and the physical properties of matter and radiation.'
          ),
          (
            'First Law of Thermodynamics',
            'Energy cannot be created or destroyed, only transformed. ΔU = Q - W, where ΔU is the change in internal energy, Q is heat added to the system, and W is work done by the system.'
          ),
          (
            'Second Law of Thermodynamics',
            'Heat flows spontaneously from a hotter body to a cooler body. The entropy of an isolated system always increases over time.'
          ),
          (
            'Carnot Engine',
            'The Carnot engine is a theoretical thermodynamic cycle that provides an upper limit on the efficiency that any classical thermodynamic engine can achieve. η = 1 - T₂/T₁'
          ),
          (
            'Entropy',
            'Entropy is a measure of the disorder or randomness in a system. ΔS = Q/T for a reversible process. The total entropy of the universe always increases.'
          ),
          (
            'Applications',
            'Thermodynamics is applied in heat engines, refrigerators, air conditioners, power plants, and chemical reactions. Understanding these principles is essential for engineering.'
          ),
        ],
      },
      {
        'title': 'Quantum Mechanics Intro',
        'pages': 18,
        'isNew': true,
        'content': [
          (
            'What is Quantum Mechanics?',
            'Quantum mechanics is a fundamental theory in physics that provides a description of the physical properties of nature at the scale of atoms and subatomic particles.'
          ),
          (
            'Wave-Particle Duality',
            'Light and matter exhibit properties of both waves and particles. The double-slit experiment demonstrates this duality — particles create an interference pattern when not observed.'
          ),
          (
            'Heisenberg Uncertainty Principle',
            'It is impossible to simultaneously know both the exact position and exact momentum of a particle. Δx · Δp ≥ ℏ/2. This is a fundamental property of nature, not a measurement limitation.'
          ),
          (
            'Schrödinger Equation',
            'The Schrödinger equation describes how the quantum state of a physical system changes over time. iℏ ∂ψ/∂t = Ĥψ, where ψ is the wave function and Ĥ is the Hamiltonian operator.'
          ),
          (
            'Quantum Numbers',
            'Electrons in atoms are described by four quantum numbers: n (principal), l (azimuthal), m (magnetic), and s (spin). These determine the energy levels and orbitals of electrons.'
          ),
        ],
      },
      {
        'title': 'Wave Optics Chapter',
        'pages': 32,
        'isNew': false,
        'content': [
          (
            'Nature of Light',
            'Light is an electromagnetic wave that travels at 3×10⁸ m/s in vacuum. It exhibits wave properties such as interference, diffraction, and polarization.'
          ),
          (
            'Huygens Principle',
            'Every point on a wavefront acts as a source of secondary wavelets. The new wavefront is the tangent to all these secondary wavelets. This explains reflection and refraction.'
          ),
          (
            'Interference of Light',
            'When two coherent light waves superpose, they produce alternating bright and dark fringes. Constructive interference: path difference = nλ. Destructive: path difference = (2n+1)λ/2.'
          ),
          (
            "Young's Double Slit Experiment",
            'Two coherent sources produce an interference pattern on a screen. Fringe width β = λD/d, where D is the distance to screen and d is the slit separation.'
          ),
          (
            'Diffraction',
            'Bending of light around obstacles or through slits. Single slit diffraction produces a central maximum with alternating minima and maxima on either side.'
          ),
          (
            'Polarization',
            'Transverse waves can be polarized. Light can be polarized by reflection, refraction, scattering, or using a polaroid. Malus Law: I = I₀cos²θ.'
          ),
        ],
      },
    ],
    'Maths': [
      {
        'title': 'Calculus Problem Set',
        'pages': 15,
        'isNew': true,
        'content': [
          (
            'Limits and Continuity',
            'A limit describes the value a function approaches as the input approaches a value. lim(x→a) f(x) = L. A function is continuous if the limit equals the function value at that point.'
          ),
          (
            'Differentiation Rules',
            'Power Rule: d/dx(xⁿ) = nxⁿ⁻¹. Product Rule: d/dx(uv) = u\'v + uv\'. Chain Rule: d/dx[f(g(x))] = f\'(g(x))·g\'(x). Quotient Rule: d/dx(u/v) = (u\'v - uv\')/v².'
          ),
          (
            'Applications of Derivatives',
            'Derivatives are used to find maxima and minima, rates of change, tangent lines, and to solve optimization problems. At a maximum or minimum, f\'(x) = 0.'
          ),
          (
            'Integration',
            'Integration is the reverse of differentiation. ∫xⁿ dx = xⁿ⁺¹/(n+1) + C. The definite integral ∫ₐᵇ f(x)dx gives the area under the curve from a to b.'
          ),
          (
            'Practice Problems',
            '1. Find dy/dx for y = 3x⁴ - 2x³ + 5x - 7\n2. Evaluate ∫(2x³ - 4x + 1)dx\n3. Find the maximum value of f(x) = -x² + 6x - 5\n4. Calculate ∫₀² (x² + 1)dx'
          ),
        ],
      },
      {
        'title': 'Integration Techniques',
        'pages': 20,
        'isNew': false,
        'content': [
          (
            'Substitution Method',
            'Used when the integrand contains a composite function. Let u = g(x), then du = g\'(x)dx. Replace and integrate with respect to u, then substitute back.'
          ),
          (
            'Integration by Parts',
            '∫u dv = uv - ∫v du. Choose u and dv using LIATE rule: Logarithmic, Inverse trig, Algebraic, Trigonometric, Exponential.'
          ),
          (
            'Partial Fractions',
            'Used to integrate rational functions. Decompose the fraction into simpler fractions. For distinct linear factors: A/(x-a) + B/(x-b). Then integrate each term separately.'
          ),
          (
            'Trigonometric Integrals',
            '∫sin²x dx = x/2 - sin(2x)/4 + C. ∫cos²x dx = x/2 + sin(2x)/4 + C. Use reduction formulas for higher powers of sin and cos.'
          ),
        ],
      },
    ],
    'Chemistry': [
      {
        'title': 'Organic Chemistry Notes',
        'pages': 28,
        'isNew': false,
        'content': [
          (
            'Introduction to Organic Chemistry',
            'Organic chemistry is the study of carbon-containing compounds. Carbon forms 4 covalent bonds and can form chains, rings, and complex structures with other elements.'
          ),
          (
            'Functional Groups',
            'Functional groups determine the chemical properties of organic molecules. Key groups: -OH (alcohol), -COOH (carboxylic acid), -CHO (aldehyde), -CO- (ketone), -NH₂ (amine).'
          ),
          (
            'Hydrocarbons',
            'Alkanes (CₙH₂ₙ₊₂): single bonds, saturated. Alkenes (CₙH₂ₙ): double bonds. Alkynes (CₙH₂ₙ₋₂): triple bonds. Aromatic: benzene ring structure.'
          ),
          (
            'Reactions',
            'Substitution, addition, elimination, and oxidation-reduction are the main types of organic reactions. Mechanism involves breaking and forming covalent bonds.'
          ),
          (
            'Isomerism',
            'Structural isomers have the same molecular formula but different structural arrangements. Stereoisomers have the same connectivity but different spatial arrangements.'
          ),
        ],
      },
      {
        'title': 'Periodic Table Guide',
        'pages': 12,
        'isNew': true,
        'content': [
          (
            'Structure of the Periodic Table',
            'Elements are arranged by increasing atomic number. Periods (rows) indicate the number of electron shells. Groups (columns) indicate the number of valence electrons.'
          ),
          (
            'Periodic Trends',
            'Atomic radius decreases across a period and increases down a group. Ionization energy increases across a period. Electronegativity increases across a period and decreases down a group.'
          ),
          (
            'Groups and Their Properties',
            'Group 1 (Alkali metals): highly reactive, form +1 ions. Group 17 (Halogens): reactive nonmetals, form -1 ions. Group 18 (Noble gases): inert, full outer shells.'
          ),
          (
            'Transition Metals',
            'Located in the d-block (groups 3-12). Have variable oxidation states, form colored compounds, and are good catalysts. Examples: Fe, Cu, Zn, Cr, Mn.'
          ),
        ],
      },
    ],
    'English': [
      {
        'title': 'Grammar Handbook',
        'pages': 45,
        'isNew': false,
        'content': [
          (
            'Parts of Speech',
            'Noun: names a person, place, thing, or idea. Verb: expresses action or state of being. Adjective: modifies a noun. Adverb: modifies a verb, adjective, or another adverb.'
          ),
          (
            'Tenses',
            'Simple Present: I write. Present Continuous: I am writing. Simple Past: I wrote. Past Continuous: I was writing. Future: I will write. Perfect tenses use have/has/had + past participle.'
          ),
          (
            'Active and Passive Voice',
            'Active: Subject performs the action. "The teacher taught the lesson." Passive: Subject receives the action. "The lesson was taught by the teacher." Use passive when the doer is unknown.'
          ),
          (
            'Direct and Indirect Speech',
            'Direct speech quotes exact words: He said, "I am tired." Indirect speech reports the meaning: He said that he was tired. Note the change in tense and pronouns.'
          ),
          (
            'Essay Writing',
            'Structure: Introduction (hook + thesis), Body paragraphs (topic sentence + evidence + analysis), Conclusion (restate thesis + broader implications). Use transitions between paragraphs.'
          ),
        ],
      },
    ],
    'CS': [
      {
        'title': 'Python Basics',
        'pages': 30,
        'isNew': true,
        'content': [
          (
            'Introduction to Python',
            'Python is a high-level, interpreted programming language known for its simplicity and readability. It supports multiple programming paradigms including procedural, object-oriented, and functional.'
          ),
          (
            'Variables and Data Types',
            'Variables store data values. Python has: int (integers), float (decimals), str (strings), bool (True/False), list (ordered collection), dict (key-value pairs), tuple (immutable list).'
          ),
          (
            'Control Flow',
            'if/elif/else for conditional execution. for loops iterate over sequences. while loops repeat while a condition is true. break exits a loop, continue skips to the next iteration.'
          ),
          (
            'Functions',
            'def function_name(parameters): defines a function. Functions can return values using return. Default parameters, *args, and **kwargs allow flexible function signatures.'
          ),
          (
            'Object-Oriented Programming',
            'Classes define objects with attributes and methods. class MyClass: defines a class. __init__ is the constructor. self refers to the instance. Inheritance allows code reuse.'
          ),
        ],
      },
      {
        'title': 'Data Structures',
        'pages': 22,
        'isNew': false,
        'content': [
          (
            'Arrays and Lists',
            'Arrays store elements of the same type in contiguous memory. Lists in Python are dynamic arrays. Access by index O(1), insertion/deletion O(n). Used for ordered collections.'
          ),
          (
            'Stacks and Queues',
            'Stack: LIFO (Last In First Out). Operations: push, pop, peek. Queue: FIFO (First In First Out). Operations: enqueue, dequeue. Both can be implemented using lists or linked lists.'
          ),
          (
            'Linked Lists',
            'A sequence of nodes where each node contains data and a pointer to the next node. Singly linked: one direction. Doubly linked: both directions. Insertion/deletion O(1) at known position.'
          ),
          (
            'Trees and Graphs',
            'Binary tree: each node has at most 2 children. BST: left < root < right. Graph: nodes connected by edges. BFS uses a queue, DFS uses a stack or recursion for traversal.'
          ),
        ],
      },
    ],
  };

  // ── Build a proper PDF for a given material ───────────────────────────────
  Future<Uint8List> _buildPdf(Map<String, dynamic> material) async {
    final pdf = pw.Document();
    final title = material['title'] as String;
    final pages = material['pages'] as int;
    final content = material['content'] as List<(String, String)>;
    final dateStr = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1A6FDB),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('EDUSPHERE ERP — E-Library',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
            ],
          ),
        ),
        footer: (ctx) => pw.Center(
          child: pw.Text(
            '© 2026 EduSphere ERP Systems — Study Material',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) => [
          // Title block
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            margin: const pw.EdgeInsets.only(bottom: 20),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1A6FDB))),
                pw.SizedBox(height: 6),
                pw.Text(
                    'Subject: $_subject  •  $pages pages  •  Generated: $dateStr',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey600)),
              ],
            ),
          ),
          // Content sections
          ...content.map((section) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8F1FB),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      section.$1,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF1A6FDB)),
                    ),
                  ),
                  pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(left: 4, right: 4, bottom: 16),
                    child: pw.Text(
                      section.$2,
                      style: const pw.TextStyle(
                          fontSize: 11, lineSpacing: 4, color: PdfColors.black),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );

    return pdf.save();
  }

  // ── View: open inline PDF viewer ──────────────────────────────────────────
  Future<void> _viewDocument(
      BuildContext context, Map<String, dynamic> material) async {
    try {
      final bytes = await _buildPdf(material);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${(material['title'] as String).replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        showToast(context, 'Could not open document', isError: true);
      }
    }
  }

  // ── Download: share sheet → user picks save location ─────────────────────
  Future<void> _downloadDocument(
      BuildContext context, Map<String, dynamic> material) async {
    try {
      final bytes = await _buildPdf(material);
      final fileName =
          '${(material['title'] as String).replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${material['title']} — choose where to save',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ]),
            backgroundColor: AppColors.studentPrimary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, 'Download failed', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _materials[_subject] ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          PageHeader(
              title: 'Study Materials',
              subtitle: 'E-Library',
              theme: roleThemes['student']!),
          // Subject filter tabs
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subjects
                    .map((s) => GestureDetector(
                          onTap: () => setState(() => _subject = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: 8.w),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: _subject == s
                                  ? AppColors.studentPrimary
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(s,
                                style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    color: _subject == s
                                        ? Colors.white
                                        : AppColors.textLight)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          // Material list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                return Container(
                  margin: EdgeInsets.only(bottom: 14.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      // Title row
                      Row(children: [
                        Container(
                          width: 52.w,
                          height: 60.h,
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.red.shade100)),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.red.shade400, size: 24.sp),
                                Text('PDF',
                                    style: GoogleFonts.inter(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red.shade400)),
                              ]),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(m['title'] as String,
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textDark)),
                                  ),
                                  if (m['isNew'] == true)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                          color: AppColors.studentPrimary,
                                          borderRadius:
                                              BorderRadius.circular(6.r)),
                                      child: Text('NEW',
                                          style: GoogleFonts.inter(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white)),
                                    ),
                                ]),
                                SizedBox(height: 4.h),
                                Text('${m['pages']} pages • $_subject',
                                    style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: AppColors.textMedium)),
                              ]),
                        ),
                      ]),
                      SizedBox(height: 14.h),
                      // Action buttons
                      Row(children: [
                        // VIEW button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _viewDocument(context, m),
                            icon: Icon(Icons.visibility_rounded, size: 16.sp),
                            label: Text('View',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.studentPrimary,
                              side: const BorderSide(
                                  color: AppColors.studentPrimary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        // DOWNLOAD button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadDocument(context, m),
                            icon: Icon(Icons.download_rounded, size: 16.sp),
                            label: Text('Download',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.studentPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
