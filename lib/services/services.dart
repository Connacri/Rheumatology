// ═══════════════════════════════════════════════════════════════════
// services/program_service.dart
// ═══════════════════════════════════════════════════════════════════
import '../models/models.dart';

class ProgramService {
  static List<CongressSession> get allSessions => _sessions;

  static List<CongressSession> sessionsForDay(DateTime day) =>
      _sessions.where((s) => s.date.day == day.day).toList();

  static CongressSession? currentSession(DateTime now) {
    final today = sessionsForDay(now);
    for (int i = 0; i < today.length; i++) {
      final s    = today[i];
      final next = i < today.length - 1 ? today[i + 1] : null;
      final start = _dt(s);
      final end   = next != null
          ? _dt(next)
          : start.add(const Duration(minutes: 30));
      if (now.isAfter(start) && now.isBefore(end)) return s;
    }
    return null;
  }

  static DateTime _dt(CongressSession s) {
    final parts = s.startTime.replaceAll('h', ':').split(':');
    return DateTime(
      s.date.year, s.date.month, s.date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '00') ?? 0,
    );
  }

  // ── Données complètes du programme ─────────────────────────────
  static final List<CongressSession> _sessions = [
    // ─── JEUDI 23 AVRIL ─────────────────────────────────────────
    CongressSession(id:1, date:DateTime(2026,4,23), startTime:'13h00',
      title:'Accueil des invités et inscription', type:'ceremony', sessionNumber:0),
    CongressSession(id:2, date:DateTime(2026,4,23), startTime:'14h00',
      title:'Cérémonie d\'ouverture', type:'ceremony', sessionNumber:0),

    // Session 1
    CongressSession(id:3, date:DateTime(2026,4,23), startTime:'14h30', endTime:'14h55',
      title:'Management of hyperparathyroidism',
      speakerName:'Ibrahim Medhet', speakerCountry:'Égypte (Le Caire)',
      type:'talk', sessionNumber:1),
    CongressSession(id:4, date:DateTime(2026,4,23), startTime:'14h55', endTime:'15h20',
      title:'Customized Management of Osteoporosis Beyond WHO Guidelines',
      speakerName:'Basel K Masri', speakerCountry:'Jordanie (Amman)',
      type:'talk', sessionNumber:1),
    CongressSession(id:5, date:DateTime(2026,4,23), startTime:'15h20', endTime:'15h35',
      title:'Behind the fracture: A Forgotten Diagnosis in Men',
      speakerName:'Boukabous Abdenour', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:1),
    CongressSession(id:6, date:DateTime(2026,4,23), startTime:'15h35', endTime:'15h55',
      title:'Updates of osteoporosis of chronic inflammatory rheumatism',
      speakerName:'Ouafi Mouloud', speakerCountry:'France (Paris)',
      type:'talk', sessionNumber:1),
    CongressSession(id:7, date:DateTime(2026,4,23), startTime:'15h55', endTime:'16h15',
      title:'Fractures in elderly subjects',
      speakerName:'Yakoubi Mustapha', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:1),
    CongressSession(id:8, date:DateTime(2026,4,23), startTime:'16h15', endTime:'16h45',
      title:'Symposium AMGEN — Denosumab in Osteoporosis',
      speakerName:'Medjadi Mohsine', speakerCountry:'Algérie (Oran)',
      type:'symposium', sessionNumber:1),
    CongressSession(id:9, date:DateTime(2026,4,23), startTime:'16h45', endTime:'17h05',
      title:'Débat', type:'break', sessionNumber:1),
    CongressSession(id:10, date:DateTime(2026,4,23), startTime:'17h05', endTime:'17h30',
      title:'Pause café', type:'break', sessionNumber:0),

    // Session 2
    CongressSession(id:11, date:DateTime(2026,4,23), startTime:'17h30', endTime:'17h55',
      title:'Botulinum toxin: pain reliever of tomorrow? Of today?',
      speakerName:'Viel Eric', speakerCountry:'France (Nîmes)',
      type:'talk', sessionNumber:2),
    CongressSession(id:12, date:DateTime(2026,4,23), startTime:'17h55', endTime:'18h10',
      title:'Immunomodulatory Properties of Baclofen and Novel Structural Analogue',
      speakerName:'Keniche Assia', speakerCountry:'Algérie (Tlemcen)',
      type:'talk', sessionNumber:2),
    CongressSession(id:13, date:DateTime(2026,4,23), startTime:'18h10', endTime:'18h35',
      title:'Concept du "Care or healing" à travers l\'Evidence-Based Medicine',
      speakerName:'Djebbar Mourad', speakerCountry:'Algérie (Oran)',
      type:'talk', sessionNumber:2),
    CongressSession(id:14, date:DateTime(2026,4,23), startTime:'18h35', endTime:'18h55',
      title:'Long-term corticosteroid therapy in 2026',
      speakerName:'Merad Samir', speakerCountry:'Algérie (Oran)',
      type:'talk', sessionNumber:2),
    CongressSession(id:15, date:DateTime(2026,4,23), startTime:'18h55', endTime:'19h25',
      title:'Symposium Pharmadis — Management of corticosteroids on RA',
      speakerName:'Khaled Tarek', speakerCountry:'Algérie (Constantine)',
      type:'symposium', sessionNumber:2),
    CongressSession(id:16, date:DateTime(2026,4,23), startTime:'19h25',
      title:'Débat', type:'break', sessionNumber:2),

    // ─── VENDREDI 24 AVRIL ──────────────────────────────────────
    // Workshops
    CongressSession(id:17, date:DateTime(2026,4,24), startTime:'08h30', endTime:'09h20',
      title:'Workshop 1 — Interventional ultrasound of the knee «beyond the barrier»',
      speakerName:'Dr Belmouhoub Abdessamad', speakerCountry:'France (Privas)',
      type:'workshop', sessionNumber:0, hall:'Salle Mascara'),
    CongressSession(id:18, date:DateTime(2026,4,24), startTime:'08h30', endTime:'09h20',
      title:'Workshop 2 — When RA Isn\'t typical: Navigating Diagnostic Challenges',
      speakerName:'Pr Acheli Dehbia', speakerCountry:'Algérie (Alger)',
      type:'workshop', sessionNumber:0, hall:'Salle Tlemcen'),
    CongressSession(id:19, date:DateTime(2026,4,24), startTime:'08h30', endTime:'09h20',
      title:'Workshop 3 — Dupuytren\'s needle aponeurotomy',
      speakerName:'Pr Touzi Mongi', speakerCountry:'Tunisie (Monastir)',
      type:'workshop', sessionNumber:0, hall:'Salle Chlef'),
    CongressSession(id:20, date:DateTime(2026,4,24), startTime:'08h30', endTime:'09h20',
      title:'Workshop 4 — Capillaroscopy',
      speakerName:'Pr Rahou Amine', speakerCountry:'Algérie (Oran)',
      type:'workshop', sessionNumber:0, hall:'Salle Saida'),
    CongressSession(id:21, date:DateTime(2026,4,24), startTime:'08h30', endTime:'09h20',
      title:'Workshop 5 — Clinical cases: Spinal Pathologies',
      speakerName:'Dr Rouidi Sid Ahmed', speakerCountry:'France (Châteaudun)',
      type:'workshop', sessionNumber:0, hall:'Salle Andalous'),

    // Session 3
    CongressSession(id:22, date:DateTime(2026,4,24), startTime:'09h20', endTime:'09h40',
      title:'Juvenile idiopathic arthritis',
      speakerName:'Hashad Soad Salem', speakerCountry:'Libye (Tripoli)',
      type:'talk', sessionNumber:3),
    CongressSession(id:23, date:DateTime(2026,4,24), startTime:'09h40', endTime:'10h00',
      title:'Rheumatoid Vasculitis',
      speakerName:'Huseynova Nargiz', speakerCountry:'Azerbaïdjan (Bakou)',
      type:'talk', sessionNumber:3),
    CongressSession(id:24, date:DateTime(2026,4,24), startTime:'10h00', endTime:'10h20',
      title:'The new role of AI in managing patients with autoimmune diseases',
      speakerName:'Ghadanfar Yaser', speakerCountry:'Koweït',
      type:'talk', sessionNumber:3),
    CongressSession(id:25, date:DateTime(2026,4,24), startTime:'10h20', endTime:'11h05',
      title:'Symposium Johnson & Johnson — Role of IL-23 inhibitors',
      speakerName:'Bengana Bilal', speakerCountry:'Algérie (Alger)',
      type:'symposium', sessionNumber:3),
    CongressSession(id:26, date:DateTime(2026,4,24), startTime:'11h05', endTime:'11h20',
      title:'PSORIATIC ARTHRITIS: Predicting its appearance for better management',
      speakerName:'Bouziane Kheira', speakerCountry:'Algérie (Oran)',
      type:'talk', sessionNumber:3),
    CongressSession(id:27, date:DateTime(2026,4,24), startTime:'11h20', endTime:'11h35',
      title:'Psoriatic arthritis is difficult to treat',
      speakerName:'Abdelaoui Selma', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:3),
    CongressSession(id:28, date:DateTime(2026,4,24), startTime:'11h35', endTime:'12h20',
      title:'Symposium Biopharm Lilly — Spondyloarthropathies 2026: Anti-IL-17 Therapy',
      speakerName:'Pr Durez Patrick', speakerCountry:'Belgique (Bruxelles)',
      type:'symposium', sessionNumber:3),
    CongressSession(id:29, date:DateTime(2026,4,24), startTime:'12h20', endTime:'13h00',
      title:'Débat', type:'break', sessionNumber:3),
    CongressSession(id:30, date:DateTime(2026,4,24), startTime:'13h00', endTime:'14h30',
      title:'Déjeuner', type:'break', sessionNumber:0),

    // Session 4
    CongressSession(id:31, date:DateTime(2026,4,24), startTime:'14h30', endTime:'15h00',
      title:'Maghreb recommendations for musculoskeletal ultrasound in RA',
      speakerName:'Haddouche Assia & Slimani Samy', speakerCountry:'Algérie (Batna)',
      type:'talk', sessionNumber:4),
    CongressSession(id:32, date:DateTime(2026,4,24), startTime:'15h00', endTime:'15h30',
      title:'What\'s new in interventional rheumatology?',
      speakerName:'Ould Henia Ahmed', speakerCountry:'France (Chartres)',
      type:'talk', sessionNumber:4),
    CongressSession(id:33, date:DateTime(2026,4,24), startTime:'15h30', endTime:'15h50',
      title:'Gout: Epidemiology, Clinical characteristics and management strategies',
      speakerName:'Kurmann Patric Thierry', speakerCountry:'Suisse (Neuchâtel)',
      type:'talk', sessionNumber:4),
    CongressSession(id:34, date:DateTime(2026,4,24), startTime:'15h50', endTime:'16h10',
      title:'Updates Criteria for pseudo gout',
      speakerName:'El Sayed Rageh', speakerCountry:'Égypte (Tanta)',
      type:'talk', sessionNumber:4, isZoom:true),
    CongressSession(id:35, date:DateTime(2026,4,24), startTime:'16h10', endTime:'16h25',
      title:'Surgical treatment of osteonecrosis of the hip',
      speakerName:'Amouri Saadedine Hichem', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:4),
    CongressSession(id:36, date:DateTime(2026,4,24), startTime:'16h25', endTime:'16h40',
      title:'Current trends in the management of rheumatoid Wrist',
      speakerName:'Bessaa Fouad', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:4),
    CongressSession(id:37, date:DateTime(2026,4,24), startTime:'16h40', endTime:'17h15',
      title:'Symposium SANOFI — Early recognition of Mucopolysaccharidosis type 1',
      speakerName:'Bencharif Imene', speakerCountry:'Algérie (Constantine)',
      type:'symposium', sessionNumber:4),
    CongressSession(id:38, date:DateTime(2026,4,24), startTime:'17h15', endTime:'18h10',
      title:'Débat', type:'break', sessionNumber:4),
    CongressSession(id:39, date:DateTime(2026,4,24), startTime:'18h10',
      title:'Pause café', type:'break', sessionNumber:0),

    // ─── SAMEDI 25 AVRIL ────────────────────────────────────────
    // Session 5
    CongressSession(id:40, date:DateTime(2026,4,25), startTime:'08h30', endTime:'08h45',
      title:'Inflammatory rheumatism and work',
      speakerName:'Bordji Youcef', speakerCountry:'Algérie (Ain-Témouchent)',
      type:'talk', sessionNumber:5),
    CongressSession(id:41, date:DateTime(2026,4,25), startTime:'08h45', endTime:'09h05',
      title:'Diet and rheumatism',
      speakerName:'Bencharif Imene', speakerCountry:'Algérie (Constantine)',
      type:'talk', sessionNumber:5),
    CongressSession(id:42, date:DateTime(2026,4,25), startTime:'09h05', endTime:'09h25',
      title:'Rheumatoid Vasculitis',
      speakerName:'Huseynova Nargiz', speakerCountry:'Azerbaïdjan (Bakou)',
      type:'talk', sessionNumber:5),
    CongressSession(id:43, date:DateTime(2026,4,25), startTime:'09h25', endTime:'09h45',
      title:'RA-ILD (Rheumatoid Arthritis — Interstitial Lung Disease)',
      speakerName:'Elomir Mohammed', speakerCountry:'Arabie Saoudite (Abha)',
      type:'talk', sessionNumber:5),
    CongressSession(id:44, date:DateTime(2026,4,25), startTime:'09h45', endTime:'10h05',
      title:'Stress and rheumatic diseases',
      speakerName:'Ndiaye Abdou Rajack', speakerCountry:'Sénégal (Dakar)',
      type:'talk', sessionNumber:5),
    CongressSession(id:45, date:DateTime(2026,4,25), startTime:'10h05', endTime:'10h35',
      title:'Symposium Johnson & Johnson — Role of Golimumab in inflammatory rheumatism',
      speakerName:'Dr Medjadi Mohsine', speakerCountry:'Algérie (Oran)',
      type:'symposium', sessionNumber:5),
    CongressSession(id:46, date:DateTime(2026,4,25), startTime:'10h35', endTime:'10h50',
      title:'Débat', type:'break', sessionNumber:5),
    CongressSession(id:47, date:DateTime(2026,4,25), startTime:'10h50',
      title:'Pause café', type:'break', sessionNumber:0),

    // Session 6
    CongressSession(id:48, date:DateTime(2026,4,25), startTime:'11h10', endTime:'11h35',
      title:'Overcoming Diagnostic Delays in Axial Spondyloarthritis',
      speakerName:'Duruoz Tuncay', speakerCountry:'Turquie (Istanbul)',
      type:'talk', sessionNumber:6),
    CongressSession(id:49, date:DateTime(2026,4,25), startTime:'11h35', endTime:'11h55',
      title:'Structural Progression in axial Spondyloarthritis',
      speakerName:'Abi Ayad Abdelatif', speakerCountry:'Algérie (Tlemcen)',
      type:'talk', sessionNumber:6),
    CongressSession(id:50, date:DateTime(2026,4,25), startTime:'11h55', endTime:'12h15',
      title:'Difficult To-Treat Spondyloarthritis (SPA)',
      speakerName:'Hadiyeva Shahla', speakerCountry:'Azerbaïdjan (Bakou)',
      type:'talk', sessionNumber:6),
    CongressSession(id:51, date:DateTime(2026,4,25), startTime:'12h15', endTime:'12h35',
      title:'Axial spondyloarthritis associated with IBD',
      speakerName:'Sahli Hela', speakerCountry:'Tunisie',
      type:'talk', sessionNumber:6),
    CongressSession(id:52, date:DateTime(2026,4,25), startTime:'12h35', endTime:'12h55',
      title:'IBD and its treatment',
      speakerName:'Gamar Leila', speakerCountry:'Algérie (Alger)',
      type:'talk', sessionNumber:6),
    CongressSession(id:53, date:DateTime(2026,4,25), startTime:'12h55', endTime:'13h00',
      title:'Symposium Roche — Role of Tocilizumab in the management of RA',
      speakerName:'Lamri Zahia', speakerCountry:'Algérie (Oran)',
      type:'symposium', sessionNumber:6),
    CongressSession(id:54, date:DateTime(2026,4,25), startTime:'13h00',
      title:'Débat', type:'break', sessionNumber:6),
    CongressSession(id:55, date:DateTime(2026,4,25), startTime:'14h30',
      title:'🏆 Clôture du congrès et cérémonie de remise des prix',
      type:'ceremony', sessionNumber:0),
    CongressSession(id:56, date:DateTime(2026,4,25), startTime:'14h30',
      title:'Déjeuner de clôture', type:'break', sessionNumber:0),
  ];
}



