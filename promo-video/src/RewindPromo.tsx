import React from 'react';
import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

const C = {
  ink: '#1E2631',
  muted: '#747E8D',
  blue: '#1A6EFC',
  blue2: '#6CB5FF',
  paper: '#F8F5EF',
  white: '#FFFFFF',
  border: '#D9DEE5',
  black: '#090B0E',
  green: '#20B875',
  violet: '#7D66F5',
  coral: '#F16F68',
  amber: '#EBA63D',
};

const sans = '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif';
const mono = '"SFMono-Regular", Menlo, Monaco, Consolas, monospace';
const serif = 'Iowan Old Style, Baskerville, Georgia, serif';

const clamp = (value: number) => Math.max(0, Math.min(1, value));
const fade = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

const FrostedPill: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({children, style}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      padding: '10px 16px',
      borderRadius: 999,
      border: '1px solid rgba(255,255,255,0.72)',
      background: 'rgba(255,255,255,0.68)',
      boxShadow: '0 10px 34px rgba(38,73,121,0.10)',
      backdropFilter: 'blur(16px)',
      color: C.ink,
      fontFamily: sans,
      fontSize: 17,
      fontWeight: 650,
      letterSpacing: '-0.01em',
      ...style,
    }}
  >
    {children}
  </div>
);

const Dot: React.FC<{color?: string; size?: number}> = ({color = C.blue, size = 8}) => (
  <span
    style={{
      width: size,
      height: size,
      borderRadius: '50%',
      background: color,
      display: 'inline-block',
      boxShadow: `0 0 0 5px ${color}20`,
    }}
  />
);

const AppIcon: React.FC<{size?: number}> = ({size = 82}) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.25,
      display: 'grid',
      placeItems: 'center',
      background: 'linear-gradient(145deg, #2884FF 0%, #0E5EE8 58%, #0A45BE 100%)',
      border: '1px solid rgba(255,255,255,0.55)',
      boxShadow: `inset 0 1px 1px rgba(255,255,255,0.45), 0 ${size * 0.18}px ${size * 0.45}px rgba(20,84,182,0.28)`,
      position: 'relative',
      overflow: 'hidden',
    }}
  >
    <div
      style={{
        position: 'absolute',
        width: '92%',
        height: '92%',
        borderRadius: '50%',
        border: `${Math.max(2, size * 0.035)}px solid rgba(255,255,255,0.18)`,
      }}
    />
    <div
      style={{
        width: size * 0.42,
        height: size * 0.42,
        border: `${Math.max(3, size * 0.065)}px solid white`,
        borderRightColor: 'transparent',
        borderRadius: '50%',
        transform: 'rotate(-35deg)',
        position: 'relative',
      }}
    >
      <div
        style={{
          position: 'absolute',
          right: -size * 0.095,
          top: -size * 0.035,
          width: 0,
          height: 0,
          borderTop: `${size * 0.07}px solid transparent`,
          borderBottom: `${size * 0.07}px solid transparent`,
          borderLeft: `${size * 0.11}px solid white`,
          transform: 'rotate(7deg)',
        }}
      />
    </div>
  </div>
);

const AmbientBackground: React.FC = () => {
  const frame = useCurrentFrame();
  const drift = Math.sin(frame / 95) * 22;

  return (
    <AbsoluteFill
      style={{
        background: C.paper,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: 0.46,
          backgroundImage:
            'radial-gradient(circle at center, rgba(30,38,49,0.11) 1.2px, transparent 1.2px)',
          backgroundSize: '31px 31px',
          transform: `translate(${drift * 0.15}px, ${drift * 0.08}px)`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 900,
          height: 900,
          left: -360 + drift,
          top: -420,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(34,119,255,0.24), rgba(34,119,255,0) 67%)',
          filter: 'blur(12px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 980,
          height: 980,
          right: -430 - drift,
          bottom: -500,
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(105,181,255,0.25), rgba(105,181,255,0) 67%)',
          filter: 'blur(14px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'linear-gradient(115deg, rgba(255,255,255,0.08), rgba(255,255,255,0.55) 46%, rgba(255,255,255,0.04))',
        }}
      />
    </AbsoluteFill>
  );
};

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const iconIn = spring({frame, fps, config: {damping: 14, stiffness: 110, mass: 0.75}});
  const titleIn = spring({frame: frame - 12, fps, config: {damping: 18, stiffness: 100}});
  const exit = interpolate(frame, [84, 116], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.cubic),
  });
  const y = interpolate(titleIn, [0, 1], [48, 0]);

  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        opacity: exit,
        transform: `translateY(${interpolate(exit, [0, 1], [-28, 0])}px)`,
      }}
    >
      <div style={{textAlign: 'center', transform: `translateY(${y}px)`}}>
        <div style={{display: 'flex', justifyContent: 'center', marginBottom: 32, transform: `scale(${iconIn})`}}>
          <AppIcon size={92} />
        </div>
        <div
          style={{
            color: C.ink,
            fontFamily: serif,
            fontSize: 96,
            fontWeight: 600,
            lineHeight: 0.98,
            letterSpacing: '-0.055em',
            opacity: titleIn,
          }}
        >
          Your workday moves fast.
        </div>
        <div
          style={{
            color: C.blue,
            fontFamily: serif,
            fontSize: 96,
            fontWeight: 600,
            lineHeight: 1.03,
            letterSpacing: '-0.055em',
            opacity: fade(frame, 31, 20),
            transform: `translateY(${interpolate(fade(frame, 31, 20), [0, 1], [25, 0])}px)`,
          }}
        >
          Rewind remembers.
        </div>
        <div
          style={{
            marginTop: 34,
            color: C.muted,
            fontFamily: sans,
            fontSize: 23,
            fontWeight: 520,
            letterSpacing: '-0.015em',
            opacity: fade(frame, 48, 18),
          }}
        >
          A private visual timeline for macOS.
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CodePreview: React.FC<{opacity: number}> = ({opacity}) => {
  const lines = [
    ['1', 'import SwiftUI'],
    ['2', ''],
    ['3', 'struct FocusView: View {'],
    ['4', '  @State private var isLive = true'],
    ['5', ''],
    ['6', '  var body: some View {'],
    ['7', '    TimelineView(.animation) { _ in'],
    ['8', '      WorkdayCanvas(isLive: isLive)'],
    ['9', '    }'],
    ['10', '  }'],
    ['11', '}'],
  ];

  return (
    <div style={{position: 'absolute', inset: 0, opacity, background: '#101419', fontFamily: mono}}>
      <div style={{height: 36, display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px', background: '#171C23', borderBottom: '1px solid #242B35'}}>
        <span style={{width: 9, height: 9, borderRadius: 99, background: C.coral}} />
        <span style={{width: 9, height: 9, borderRadius: 99, background: C.amber}} />
        <span style={{width: 9, height: 9, borderRadius: 99, background: C.green}} />
        <span style={{marginLeft: 14, color: '#9BA7B5', fontSize: 10}}>FocusView.swift</span>
      </div>
      <div style={{display: 'grid', gridTemplateColumns: '112px 1fr', height: 'calc(100% - 36px)'}}>
        <div style={{background: '#13181E', borderRight: '1px solid #242B35', padding: '14px 12px', color: '#657181', fontSize: 9, lineHeight: 2}}>
          <div style={{color: '#CAD3DE', marginBottom: 8}}>REWIND</div>
          <div>⌄ Sources</div>
          <div style={{paddingLeft: 10}}>⌄ Views</div>
          <div style={{paddingLeft: 20, color: '#90B9FF'}}>FocusView.swift</div>
          <div style={{paddingLeft: 20}}>Timeline.swift</div>
        </div>
        <div style={{padding: '18px 20px', fontSize: 11, lineHeight: 1.72}}>
          {lines.map(([n, text]) => (
            <div key={n} style={{display: 'flex'}}>
              <span style={{width: 28, color: '#4E5B69', textAlign: 'right', marginRight: 16}}>{n}</span>
              <span style={{color: text.includes('import') || text.includes('struct') ? '#CD8DF2' : text.includes('View') || text.includes('Canvas') ? '#75B7FF' : text.includes('true') ? '#F0A96C' : '#CCD5E0'}}>{text || '\u00A0'}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const DesignPreview: React.FC<{opacity: number}> = ({opacity}) => (
  <div style={{position: 'absolute', inset: 0, opacity, background: '#E9EDF3', fontFamily: sans}}>
    <div style={{height: 36, background: '#2B3039', display: 'flex', alignItems: 'center', padding: '0 14px', color: '#DCE2EA', fontSize: 10}}>
      Product canvas <span style={{marginLeft: 'auto', color: '#93A0B0'}}>84%</span>
    </div>
    <div style={{display: 'grid', gridTemplateColumns: '92px 1fr 118px', height: 'calc(100% - 36px)'}}>
      <div style={{background: '#FAFBFC', borderRight: '1px solid #D7DCE3', padding: 12, fontSize: 9, color: C.muted}}>
        <b style={{color: C.ink}}>Layers</b>
        <div style={{marginTop: 14, lineHeight: 2.1}}>⌄ Dashboard<br />　Header<br />　Timeline<br />　Summary</div>
      </div>
      <div style={{display: 'grid', placeItems: 'center', padding: 20}}>
        <div style={{width: '88%', height: '85%', borderRadius: 14, background: '#F9F6F0', boxShadow: '0 12px 35px rgba(31,43,61,0.14)', padding: 18}}>
          <div style={{fontFamily: serif, fontSize: 21, fontWeight: 600, color: C.ink}}>Today in Review</div>
          <div style={{display: 'flex', gap: 7, marginTop: 15}}>
            {[['Captures','86'],['Contexts','7'],['Top app','Xcode']].map(([a,b]) => <div key={a} style={{flex: 1, padding: 10, background: 'white', border: '1px solid #E0E4EA', borderRadius: 9}}><div style={{fontSize: 7, color: C.muted, textTransform: 'uppercase'}}>{a}</div><div style={{fontSize: 11, fontWeight: 700, marginTop: 4, color: C.ink}}>{b}</div></div>)}
          </div>
          <div style={{display: 'flex', alignItems: 'flex-end', height: 82, gap: 8, marginTop: 17, padding: '0 9px'}}>
            {[35,55,42,76,62,88,48,68,39,57].map((h, i) => <div key={i} style={{height: h, flex: 1, borderRadius: 4, background: `linear-gradient(#3B8BFF, ${i % 2 ? '#7D66F5' : '#6CB5FF'})`}} />)}
          </div>
        </div>
      </div>
      <div style={{background: '#FAFBFC', borderLeft: '1px solid #D7DCE3', padding: 12, fontSize: 9, color: C.muted}}>
        <b style={{color: C.ink}}>Design</b>
        <div style={{height: 22, marginTop: 14, background: '#EDF0F4', borderRadius: 6}} />
        <div style={{height: 22, marginTop: 7, background: '#EDF0F4', borderRadius: 6}} />
        <div style={{marginTop: 15}}>Fill</div>
        <div style={{display: 'flex', gap: 5, marginTop: 6}}><span style={{width: 20, height: 20, borderRadius: 5, background: C.blue}} /><span style={{width: 20, height: 20, borderRadius: 5, background: C.violet}} /></div>
      </div>
    </div>
  </div>
);

const BrowserPreview: React.FC<{opacity: number}> = ({opacity}) => (
  <div style={{position: 'absolute', inset: 0, opacity, background: '#EEF4FC', fontFamily: sans}}>
    <div style={{height: 40, background: '#F9FBFE', borderBottom: '1px solid #DCE3EC', display: 'flex', alignItems: 'center', padding: '0 12px', gap: 7}}>
      <span style={{width: 9, height: 9, borderRadius: 99, background: C.coral}} /><span style={{width: 9, height: 9, borderRadius: 99, background: C.amber}} /><span style={{width: 9, height: 9, borderRadius: 99, background: C.green}} />
      <div style={{marginLeft: 14, height: 23, borderRadius: 8, background: '#E9EEF5', flex: 1, display: 'grid', placeItems: 'center', color: '#7D8794', fontSize: 9}}>localhost / dashboard</div>
    </div>
    <div style={{padding: 26, height: 'calc(100% - 40px)', background: 'linear-gradient(135deg,#07162D,#102E52)'}}>
      <div style={{display: 'flex', alignItems: 'center', color: 'white', fontSize: 12, fontWeight: 700}}><span style={{width: 20, height: 20, borderRadius: 6, background: C.blue, marginRight: 8}} />NORTHSTAR <span style={{marginLeft: 'auto', fontWeight: 500, color: '#9DB0CA'}}>Overview　Projects　Team</span></div>
      <div style={{marginTop: 34, color: 'white', fontSize: 34, fontWeight: 720, letterSpacing: '-0.045em'}}>Make every signal count.</div>
      <div style={{marginTop: 10, color: '#9FB6D2', fontSize: 12, maxWidth: 330, lineHeight: 1.5}}>A focused dashboard for the decisions that move your team forward.</div>
      <div style={{display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 12, marginTop: 28}}>
        <div style={{height: 135, borderRadius: 13, background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.12)', padding: 16}}>
          <div style={{fontSize: 9, color: '#A9BAD0'}}>ACTIVE SIGNALS</div><div style={{fontSize: 25, color: 'white', fontWeight: 700, marginTop: 5}}>1,284</div>
          <svg width="100%" height="60" viewBox="0 0 280 60" style={{marginTop: 4}}><path d="M0 51 C28 40 38 49 62 32 S102 42 126 25 S164 20 182 28 S226 5 280 9" fill="none" stroke="#6CB5FF" strokeWidth="3" /><path d="M0 51 C28 40 38 49 62 32 S102 42 126 25 S164 20 182 28 S226 5 280 9 L280 60 L0 60 Z" fill="url(#g)" opacity=".3" /><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stopColor="#6CB5FF"/><stop offset="1" stopColor="#6CB5FF" stopOpacity="0"/></linearGradient></defs></svg>
        </div>
        <div style={{height: 135, borderRadius: 13, background: '#1A6EFC', padding: 16, color: 'white'}}><div style={{fontSize: 9, opacity: .75}}>FOCUS SCORE</div><div style={{fontFamily: serif, fontSize: 47, marginTop: 12}}>92</div><div style={{fontSize: 9, opacity: .72}}>↑ 8% this week</div></div>
      </div>
    </div>
  </div>
);

const ScreenPreview: React.FC<{frame: number}> = ({frame}) => {
  const design = interpolate(frame, [330, 365, 405, 438], [0, 1, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const browser = interpolate(frame, [420, 455], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const code = 1 - Math.max(design, browser);
  return (
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden', borderRadius: 14, background: '#101419'}}>
      <CodePreview opacity={code} />
      <DesignPreview opacity={design} />
      <BrowserPreview opacity={browser} />
      <div style={{position: 'absolute', inset: 0, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.1)', borderRadius: 14}} />
    </div>
  );
};

const CaptureRing: React.FC<{frame: number}> = ({frame}) => {
  const progress = ((frame - 128) % 90 + 90) % 90 / 90;
  const degrees = 360 * progress;
  const flash = frame >= 216 && frame < 233 ? interpolate(frame, [216, 220, 233], [0, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}) : 0;
  return (
    <div style={{position: 'relative', width: 46, height: 46, borderRadius: '50%', background: `conic-gradient(${C.blue} ${degrees}deg, #E7EAF0 ${degrees}deg)`, display: 'grid', placeItems: 'center', boxShadow: `0 0 0 ${flash * 18}px rgba(26,110,252,${0.18 * (1-flash)})`}}>
      <div style={{width: 36, height: 36, borderRadius: '50%', background: 'white', display: 'grid', placeItems: 'center'}}><span style={{width: 13, height: 13, borderRadius: '50%', background: '#DDEBFF'}} /></div>
    </div>
  );
};

const TimelineMarkers: React.FC<{frame: number}> = ({frame}) => {
  const phase = clamp((frame - 304) / 170);
  const selected = Math.floor(interpolate(phase, [0, 1], [5, 40]));
  const colors = [C.blue, C.blue2, C.green, C.violet, C.coral];
  return (
    <div style={{height: 50, display: 'flex', alignItems: 'flex-end', gap: 3, padding: '0 4px', overflow: 'hidden'}}>
      {Array.from({length: 48}).map((_, i) => {
        const active = Math.abs(i - selected) < 1;
        return <div key={i} style={{width: active ? 8 : 5, flex: '0 0 auto', height: active ? 48 : 37 + (i % 3) * 2, borderRadius: 4, background: colors[Math.floor(i / 8) % colors.length], opacity: active ? 1 : 0.38, border: active ? '1px solid rgba(0,0,0,.55)' : '1px solid rgba(0,0,0,.12)', boxShadow: active ? '0 4px 12px rgba(26,110,252,.25)' : 'none'}} />;
      })}
    </div>
  );
};

const SummaryPanel: React.FC<{frame: number}> = ({frame}) => {
  const reveal = fade(frame, 510, 65);
  const heat = [
    [0,1,1,2,3,4,5,4,3,2,2,1],
    [0,0,1,1,2,3,2,2,4,5,3,1],
    [1,2,2,1,0,0,1,3,3,2,1,0],
    [0,1,0,0,1,2,1,0,2,3,2,1],
  ];
  const rowColors = [C.blue, C.violet, C.green, C.coral];
  return (
    <div style={{height: '100%', border: `1px solid ${C.border}`, background: 'white', borderRadius: 18, padding: 18, boxShadow: '0 14px 34px rgba(36,62,98,.07)', overflow: 'hidden'}}>
      <div style={{fontFamily: serif, fontSize: 22, fontWeight: 600, color: C.ink}}>Today in Review</div>
      <div style={{fontSize: 10, color: C.muted, marginTop: 2}}>Timeline summaries and app/project activity heatmap.</div>
      <div style={{display: 'flex', padding: 3, background: '#F1F2F4', borderRadius: 7, marginTop: 13, fontSize: 9, fontWeight: 650}}><div style={{flex: 1, textAlign: 'center', background: 'white', borderRadius: 5, padding: 5, boxShadow: '0 1px 3px rgba(0,0,0,.12)'}}>Today</div><div style={{flex: 1, textAlign: 'center', padding: 5, color: C.muted}}>This Week</div></div>
      <div style={{display: 'flex', gap: 6, marginTop: 10}}>
        {[['CAPTURES','86'],['CONTEXTS','7'],['TOP APP','Xcode']].map(([a,b], i) => <div key={a} style={{flex: 1, padding: '8px 9px', background: '#F7F7F8', borderRadius: 8, opacity: interpolate(reveal, [0,1], [0.45,1]), transform: `translateY(${(1-reveal)*(8+i*3)}px)`}}><div style={{fontSize: 7, color: C.muted, letterSpacing: '.08em'}}>{a}</div><div style={{fontFamily: mono, fontSize: 10, color: C.ink, fontWeight: 700, marginTop: 4}}>{b}</div></div>)}
      </div>
      <div style={{height: 1, background: '#E6E8EC', margin: '13px 0 11px'}} />
      <div style={{fontSize: 9, color: C.muted, fontWeight: 700, letterSpacing: '.08em'}}>TIMELINE</div>
      <div style={{marginTop: 9, display: 'grid', gap: 8}}>
        {[['9:00 – 12:00','28 captures · Xcode / Rewind',C.blue],['12:00 – 3:00','19 captures · Figma / Dashboard',C.violet],['3:00 – 6:00','31 captures · Browser / Preview',C.green]].map(([time,label,color], i) => <div key={time} style={{display: 'flex', gap: 8, opacity: clamp((reveal*1.4)-(i*.18)), transform: `translateX(${(1-clamp((reveal*1.4)-(i*.18)))*14}px)`}}><span style={{width: 4, height: 34, borderRadius: 99, background: color}} /><div><div style={{fontFamily: mono, fontSize: 9, fontWeight: 700, color: C.ink}}>{time}</div><div style={{fontSize: 8, color: C.muted, marginTop: 3}}>{label}</div></div></div>)}
      </div>
      <div style={{fontSize: 9, color: C.muted, fontWeight: 700, letterSpacing: '.08em', marginTop: 15}}>ACTIVITY HEATMAP</div>
      <div style={{display: 'grid', gridTemplateColumns: '72px repeat(12, 1fr)', gap: 3, alignItems: 'center', marginTop: 9}}>
        {heat.flatMap((row, r) => [<div key={`l${r}`} style={{fontSize: 8, color: r === 0 ? C.ink : C.muted, overflow: 'hidden', whiteSpace: 'nowrap'}}>{['Rewind','Dashboard','Research','Messages'][r]}</div>, ...row.map((v, i) => <div key={`${r}-${i}`} style={{height: 9, borderRadius: 2.5, background: rowColors[r], opacity: v === 0 ? .08 : (.15 + v*.15) * clamp(reveal*1.35 - (i*.025))}} />)])}
      </div>
    </div>
  );
};

const AppWindow: React.FC<{frame: number}> = ({frame}) => {
  const {fps} = useVideoConfig();
  const appIn = spring({frame: frame - 82, fps, config: {damping: 17, stiffness: 85, mass: .9}});
  const exit = interpolate(frame, [690, 735], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)});
  const captureText = frame < 305;
  const scrubText = frame >= 305 && frame < 500;
  const focusSummary = interpolate(frame, [505, 570], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)});
  const scale = interpolate(appIn, [0,1], [.86,1]) * interpolate(focusSummary, [0,1], [1,1.06]);
  const translateX = interpolate(focusSummary, [0,1], [0,-185]);

  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', opacity: appIn * exit, transform: `translate(${translateX}px, ${interpolate(appIn,[0,1],[110,18])}px) scale(${scale})`, transformOrigin: 'center'}}>
      <div style={{width: 1550, height: 830, borderRadius: 28, background: C.paper, border: '1px solid rgba(135,150,170,.55)', boxShadow: '0 55px 120px rgba(31,61,105,.25), 0 8px 30px rgba(31,61,105,.12)', overflow: 'hidden', position: 'relative'}}>
        <div style={{height: 48, display: 'flex', alignItems: 'center', padding: '0 19px', gap: 9, background: 'rgba(255,255,255,.82)', borderBottom: '1px solid #E1E4E9'}}>
          {[C.coral,C.amber,C.green].map((c,i)=><span key={c} style={{width: 12, height: 12, borderRadius: 99, background: c, opacity: .9}} />)}
          <div style={{position: 'absolute', left: '50%', transform: 'translateX(-50%)', fontFamily: sans, fontSize: 12, color: '#66717F', fontWeight: 650}}>Rewind</div>
        </div>
        <div style={{padding: 20, height: 'calc(100% - 48px)', position: 'relative'}}>
          <div style={{height: 140, borderRadius: 20, background: 'white', border: `1px solid ${C.border}`, padding: '22px 24px', display: 'flex', boxShadow: '0 16px 40px rgba(45,74,115,.06)'}}>
            <div>
              <div style={{fontFamily: serif, fontSize: 43, lineHeight: 1, fontWeight: 600, color: C.ink}}>Rewind</div>
              <div style={{fontFamily: sans, fontSize: 12, color: C.muted, marginTop: 12}}>Focused-window captures in day folders, with frame-style playback.</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 9, marginTop: 15, fontFamily: mono, color: C.muted, fontSize: 10}}><Dot color={C.green} size={7}/><span>{frame < 140 ? 'Capture paused' : 'Capture enabled · every 30s'}</span></div>
            </div>
            <div style={{marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 14}}>
              <CaptureRing frame={frame} />
              <div><div style={{fontFamily: sans, fontSize: 8, letterSpacing: '.1em', color: C.muted}}>NEXT CAPTURE</div><div style={{fontFamily: mono, color: C.ink, fontSize: 10, marginTop: 5, fontWeight: 700}}>Every 30s</div></div>
              <div style={{height: 34, borderRadius: 8, padding: '0 14px', display: 'grid', placeItems: 'center', background: frame < 140 ? '#E8EAEF' : C.ink, color: frame < 140 ? C.ink : 'white', fontFamily: sans, fontSize: 10, fontWeight: 700}}>Capture <span style={{display: 'inline-flex', width: 24, height: 14, padding: 2, borderRadius: 99, background: frame < 140 ? '#B8BEC7' : C.blue, marginLeft: 7, verticalAlign: 'middle', justifyContent: frame < 140 ? 'flex-start' : 'flex-end'}}><span style={{width: 10, height: 10, background: 'white', borderRadius: 99}} /></span></div>
              <div style={{height: 34, borderRadius: 8, padding: '0 14px', display: 'grid', placeItems: 'center', border: '1px solid #D8DDE4', color: C.ink, fontFamily: sans, fontSize: 10, fontWeight: 700}}>Open Folder</div>
            </div>
          </div>
          <div style={{display: 'grid', gridTemplateColumns: '1fr 328px', gap: 16, height: 586, marginTop: 16}}>
            <div style={{border: `1px solid ${C.border}`, background: 'white', borderRadius: 20, padding: 18, boxShadow: '0 14px 34px rgba(36,62,98,.06)', overflow: 'hidden'}}>
              <div style={{height: 18, fontFamily: mono, fontSize: 9, color: C.muted, textAlign: 'right'}}>{frame < 345 ? 'Xcode' : frame < 438 ? 'Figma' : 'Browser'}　·　{frame < 345 ? '10:42:08 AM' : frame < 438 ? '11:17:31 AM' : '2:36:54 PM'}　·　842 KB</div>
              <div style={{height: 466, borderRadius: 14, position: 'relative', background: C.black, marginTop: 7, overflow: 'hidden'}}><ScreenPreview frame={frame}/></div>
              <TimelineMarkers frame={frame}/>
            </div>
            <SummaryPanel frame={frame}/>
          </div>
        </div>
      </div>
      <div style={{position: 'absolute', top: 70, left: 155, opacity: captureText ? fade(frame, 126, 22) : 0, transform: `translateY(${captureText ? interpolate(fade(frame,126,22),[0,1],[16,0]) : 0}px)`}}><FrostedPill><Dot color={C.green}/>Captures the window you’re using</FrostedPill></div>
      <div style={{position: 'absolute', top: 90, right: 90, opacity: scrubText ? fade(frame, 305, 25) : 0}}><FrostedPill><span style={{color:C.blue,fontSize:21}}>↔</span>Scroll back through every moment</FrostedPill></div>
      <div style={{position: 'absolute', top: 98, right: -40, opacity: focusSummary, transform: `translateX(${interpolate(focusSummary,[0,1],[28,0])}px)`}}><FrostedPill><span style={{color:C.violet,fontSize:20}}>✦</span>See the shape of your day</FrostedPill></div>
    </AbsoluteFill>
  );
};

const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = frame - 700;
  const inSpring = spring({frame: local, fps, config: {damping: 17, stiffness: 92}});
  const sub = fade(local, 25, 22);
  const line = fade(local, 50, 20);
  const shimmer = interpolate(local, [0, 200], [-450, 700], {extrapolateLeft: 'clamp', extrapolateRight: 'extend'});
  if (local < 0) return null;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <div style={{position: 'absolute', width: 660, height: 660, borderRadius: '50%', background: 'radial-gradient(circle, rgba(26,110,252,.16), transparent 67%)', transform: `scale(${.8 + inSpring*.3})`}} />
      <div style={{textAlign: 'center', transform: `translateY(${interpolate(inSpring,[0,1],[48,0])}px)`, opacity: inSpring}}>
        <div style={{display: 'flex', justifyContent: 'center', marginBottom: 32}}><AppIcon size={104}/></div>
        <div style={{fontFamily: serif, fontSize: 104, fontWeight: 600, lineHeight: .96, letterSpacing: '-.06em', color: C.ink}}>See your day.</div>
        <div style={{fontFamily: serif, fontSize: 104, fontWeight: 600, lineHeight: 1.02, letterSpacing: '-.06em', color: C.blue, position: 'relative', overflow: 'hidden'}}>
          Keep your flow.
          <span style={{position: 'absolute', top: 0, left: shimmer, width: 180, height: 120, transform: 'skewX(-18deg)', background: 'linear-gradient(90deg, transparent, rgba(255,255,255,.7), transparent)', opacity: .55}} />
        </div>
        <div style={{fontFamily: sans, fontSize: 25, color: C.muted, marginTop: 31, opacity: sub, letterSpacing: '-.015em'}}>Private, local, and built for macOS.</div>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, marginTop: 42, opacity: line}}>
          <div style={{height: 1, width: 54, background: '#BCC5D0'}} />
          <span style={{fontFamily: sans, fontSize: 17, color: C.ink, fontWeight: 720, letterSpacing: '.08em', textTransform: 'uppercase'}}>Rewind</span>
          <div style={{height: 1, width: 54, background: '#BCC5D0'}} />
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const RewindPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const edgeFade = interpolate(frame, [0, 12, 876, 899], [0, 1, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <AbsoluteFill style={{fontFamily: sans, opacity: edgeFade}}>
      <AmbientBackground />
      <Intro />
      <AppWindow frame={frame} />
      <EndCard />
      <div style={{position: 'absolute', inset: 0, pointerEvents: 'none', boxShadow: 'inset 0 0 150px rgba(42,63,91,.07)'}} />
    </AbsoluteFill>
  );
};
