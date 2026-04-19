document.addEventListener('DOMContentLoaded', () => {
  // Remove preloader
  setTimeout(() => {
    const preloader = document.getElementById('preloader');
    if (preloader) preloader.classList.add('hidden');
  }, 1500);

  // Supabase Initialization
  const supabaseUrl = 'https://tkmzeywijodhoudjgtxr.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrbXpleXdpam9kaG91ZGpndHhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NzgwNTEsImV4cCI6MjA5MTM1NDA1MX0.s4Ip4JHH3coBUVRmmde5gH6L9_Z4y7POXKN0l9R63AE';

  let supabase;
  try {
    supabase = window.supabase.createClient(supabaseUrl, supabaseKey);
  } catch (e) {
    console.error('Supabase failed to initialize:', e);
  }

  const registrationForm = document.getElementById('registrationForm');
  const formMessage = document.getElementById('formMessage');
  const submitBtn = document.getElementById('submitBtn');

  if (registrationForm) {
    registrationForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      submitBtn.disabled = true;
      const originalBtnText = submitBtn.innerHTML;
      submitBtn.innerHTML = '<span>⏳</span><span>Processing...</span>';
      formMessage.style.display = 'none';

      try {
        if (!supabase) throw new Error('Supabase not initialized');
        const formData = new FormData(registrationForm);
        const data = Object.fromEntries(formData.entries());

        if (data.title === 'Other') {
          data.title = data.title_other || 'Other';
        }
        if (data.medical_specialty === 'Other') {
          data.medical_specialty = data.specialty_other || 'Other';
        }

        const { error } = await supabase
          .from('congress_users')
          .insert({
            id: crypto.randomUUID(),
            first_name: data.first_name,
            last_name: data.last_name,
            email: data.email,
            phone: data.phone_number,
            country: data.city,
            specialty: data.medical_specialty,
            institution: data.healthcare_facility,
            role: 'guest',
            status: 'pending',
            admin_notes: `Title: ${data.title}${data.title_other ? ' (' + data.title_other + ')' : ''} | Participation: ${data.participation_type} | Specialty Detail: ${data.specialty_other || 'N/A'}`
          });

        if (error) throw error;

        formMessage.innerHTML = '<strong>Success!</strong> Your pre-registration has been submitted successfully. You will be contacted soon.';
        formMessage.style.background = '#dcfce7';
        formMessage.style.color = '#166534';
        formMessage.style.display = 'block';
        registrationForm.reset();
        formMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });

      } catch (err) {
        console.error('Registration error:', err);
        formMessage.innerHTML = '<strong>Error!</strong> ' + (err.message || 'Something went wrong. Please try again later.');
        formMessage.style.background = '#fee2e2';
        formMessage.style.color = '#991b1b';
        formMessage.style.display = 'block';
      } finally {
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalBtnText;
      }
    });
  }

  // Particles
  const pc = document.getElementById('particles-container');
  if (pc) {
    for (let i = 0; i < 30; i++) {
      const p = document.createElement('div');
      p.className = 'particle';
      const s = Math.random() * 8 + 3;
      p.style.cssText = `width:${s}px;height:${s}px;left:${Math.random()*100}%;background:${Math.random()>0.5?'var(--accent)':'var(--gold)'};animation-duration:${Math.random()*20+15}s;animation-delay:${Math.random()*15}s;`;
      pc.appendChild(p);
    }
  }

  // Navbar scroll effect
  const navbar = document.getElementById('navbar');
  window.addEventListener('scroll', () => navbar.classList.toggle('scrolled', window.scrollY > 50));

  // Mobile menu toggle
  const mt = document.getElementById('mobileToggle');
  const nl = document.getElementById('navLinks');

  if (mt && nl) {
    mt.addEventListener('click', (e) => {
      e.stopPropagation();
      mt.classList.toggle('active');
      nl.classList.toggle('mobile-open');
    });

    nl.querySelectorAll('a').forEach(l => {
      l.addEventListener('click', () => {
        mt.classList.remove('active');
        nl.classList.remove('mobile-open');
      });
    });

    document.addEventListener('click', (e) => {
      if (nl.classList.contains('mobile-open') && !nl.contains(e.target) && !mt.contains(e.target)) {
        mt.classList.remove('active');
        nl.classList.remove('mobile-open');
      }
    });
  }

  // Program tabs
  document.querySelectorAll('.program-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.program-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      document.querySelectorAll('.program-day').forEach(d => d.classList.remove('active'));
      document.getElementById(tab.getAttribute('data-day')).classList.add('active');
    });
  });

  // Countdown timer
  function updateCountdown() {
    const target = new Date('April 23, 2026 09:00:00').getTime();
    const now = new Date().getTime();
    const diff = target - now;
    if (diff > 0) {
      document.getElementById('countdown-days').textContent = String(Math.floor(diff/(1000*60*60*24))).padStart(3,'0');
      document.getElementById('countdown-hours').textContent = String(Math.floor((diff%(1000*60*60*24))/(1000*60*60))).padStart(2,'0');
      document.getElementById('countdown-minutes').textContent = String(Math.floor((diff%(1000*60*60))/(1000*60))).padStart(2,'0');
      document.getElementById('countdown-seconds').textContent = String(Math.floor((diff%(1000*60))/1000)).padStart(2,'0');
    }
  }
  updateCountdown();
  setInterval(updateCountdown, 1000);

  // Intersection Observer for reveal animations
  const obs = new IntersectionObserver(entries => {
    entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); });
  }, { threshold: 0.1, rootMargin: '0px -50px 0px' });
  document.querySelectorAll('.reveal,.reveal-left,.reveal-right').forEach(el => obs.observe(el));

  // Stats counter
  const co = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.querySelectorAll('.stat-num').forEach(c => {
          const target = parseInt(c.textContent);
          let cur = 0;
          const inc = target / 60;
          const timer = setInterval(() => {
            cur += inc;
            if (cur >= target) {
              c.textContent = target + '+';
              clearInterval(timer);
            } else {
              c.textContent = Math.floor(cur);
            }
          }, 30);
        });
        co.unobserve(e.target);
      }
    });
  }, { threshold: 0.5 });
  const sr = document.querySelector('.stats-row');
  if (sr) co.observe(sr);

  // Back to top button
  const btt = document.getElementById('backToTop');
  window.addEventListener('scroll', () => btt.classList.toggle('visible', window.scrollY > 500));
  btt.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

  // Smooth scroll for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', function(e) {
      e.preventDefault();
      const t = document.querySelector(this.getAttribute('href'));
      if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });

  // Load release info for Android download button
  async function loadRelease() {
    try {
      const res = await fetch(`release.json?t=${Date.now()}`, {
        cache: "no-store",
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache'
        }
      });

      if (!res.ok) {
        throw new Error(`HTTP error: ${res.status}`);
      }

      const data = await res.json();
      console.log("JSON loaded:", data);

      const btn = document.getElementById("downloadBtn");
      const text = document.getElementById("versionText");

      if (btn && data.platforms?.android?.url) {
        btn.href = data.platforms.android.url;
        console.log("Link updated:", btn.href);
      } else {
        console.warn("Button or Android URL not found");
      }

      if (text && data.version) {
        text.innerText = `Télécharger ${data.version}`;
        console.log("Text updated:", text.innerText);
      }

    } catch (error) {
      console.error("Error loading release:", error);
    }
  }

  loadRelease();
});