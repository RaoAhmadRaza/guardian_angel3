
import React, { useState, useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import { 
  Info, 
  Plus, 
  Home, 
  MapPin, 
  Store, 
  Heart, 
  Check, 
  Trash2, 
  X,
  ShieldCheck,
  LocateFixed,
  ChevronRight,
  Map as MapIcon,
  CircleDot,
  Shield
} from 'lucide-react';

/**
 * Fix: Declare the google global variable to avoid "Cannot find name 'google'" errors.
 */
declare const google: any;

// --- Types ---

type ZoneType = 'home' | 'mosque' | 'market' | 'hospital' | 'other';
type MapViewMode = 'street' | 'satellite' | 'minimal';
type ScreenMode = 'home' | 'add' | 'info';

interface SafeZone {
  id: string;
  name: string;
  type: ZoneType;
  lat: number;
  lng: number;
  radius: number;
  enabled: boolean;
  notifyOnEnter: boolean;
  notifyOnExit: boolean;
}

// Default location (e.g., near downtown London)
const DEFAULT_CENTER = { lat: 51.5074, lng: -0.1278 };

// Styles for the "Minimal" map mode
const MINIMAL_STYLE = [
  { elementType: "geometry", stylers: [{ color: "#ebe3cd" }] },
  { elementType: "labels.text.fill", stylers: [{ color: "#523735" }] },
  { elementType: "labels.text.stroke", stylers: [{ color: "#f5f1e6" }] },
  {
    featureType: "administrative",
    elementType: "geometry.stroke",
    stylers: [{ color: "#c9b2a6" }],
  },
  {
    featureType: "road",
    elementType: "geometry",
    stylers: [{ color: "#f5f1e6" }],
  },
  {
    featureType: "water",
    elementType: "geometry.fill",
    stylers: [{ color: "#b9d3c2" }],
  },
];

// --- Icons ---

const ZONE_ICONS: Record<ZoneType, React.ReactNode> = {
  home: <Home className="w-7 h-7" />,
  mosque: <CircleDot className="w-7 h-7" />,
  market: <Store className="w-7 h-7" />,
  hospital: <Heart className="w-7 h-7" />,
  other: <MapPin className="w-7 h-7" />,
};

// --- Real Map Component ---

const RealGoogleMap = ({ 
  zones, 
  center, 
  mode, 
  onMapClick 
}: { 
  zones: SafeZone[], 
  center?: { lat: number, lng: number },
  mode: MapViewMode,
  onMapClick?: (lat: number, lng: number) => void
}) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const googleMap = useRef<any>(null);
  const circles = useRef<any[]>([]);
  const [isApiLoaded, setIsApiLoaded] = useState(false);

  useEffect(() => {
    // Dynamically inject the Google Maps loader script using the provided API key
    if (!(window as any).google?.maps?.importLibrary) {
      const script = document.createElement('script');
      script.innerHTML = `
        (g=>{var h,a,k,p="The Google Maps JavaScript API",c="google",l="importLibrary",q="__ib__",m=document,b=window;b=b[c]||(b[c]={});var d=b.maps||(b.maps={}),r=new Set,e=new URLSearchParams,u=()=>h||(h=new Promise(async(f,n)=>{await (a=m.createElement("script"));e.set("libraries",[...r]+"");for(k in g)e.set(k.replace(/[A-Z]/g,t=>"_"+t[0].toLowerCase()),g[k]);e.set("callback",c+".maps."+q);a.src="https://maps."+c+"apis.com/maps/api/js?"+e;d[q]=f;a.onerror=()=>h=n(Error(p+" could not load."));a.nonce=m.querySelector("script[nonce]")?.nonce||"";m.head.append(a)}));d[l]?console.warn(p+" only loads once. Re-trying:",g):d[l]=(f,...n)=>r.add(f)&&u().then(()=>d[l](f,...n))})({
          key: "${process.env.API_KEY}",
          v: "weekly"
        });
      `;
      document.head.appendChild(script);
    }

    const checkApi = setInterval(() => {
      if ((window as any).google?.maps?.importLibrary) {
        setIsApiLoaded(true);
        clearInterval(checkApi);
      }
    }, 100);

    return () => clearInterval(checkApi);
  }, []);

  useEffect(() => {
    const initMap = async () => {
      if (!mapRef.current || !isApiLoaded) return;
      
      try {
        const { Map } = await google.maps.importLibrary("maps");
        
        googleMap.current = new Map(mapRef.current, {
          center: center || DEFAULT_CENTER,
          zoom: 15,
          disableDefaultUI: true,
          clickableIcons: false,
          mapTypeId: mode === 'satellite' ? 'satellite' : 'roadmap',
          styles: mode === 'minimal' ? MINIMAL_STYLE : [],
        });

        if (onMapClick) {
          googleMap.current.addListener('click', (e: any) => {
            if (e.latLng) onMapClick(e.latLng.lat(), e.latLng.lng());
          });
        }
      } catch (err) {
        console.error("Failed to initialize Google Map:", err);
      }
    };

    if (isApiLoaded) {
      initMap();
    }
  }, [isApiLoaded]);

  useEffect(() => {
    if (!googleMap.current) return;

    // Update map type and style
    googleMap.current.setMapTypeId(mode === 'satellite' ? 'satellite' : 'roadmap');
    googleMap.current.setOptions({ styles: mode === 'minimal' ? MINIMAL_STYLE : [] });

    // Clear old circles
    circles.current.forEach(c => c.setMap(null));
    circles.current = [];

    // Draw active safe zones
    zones.forEach(zone => {
      const circle = new google.maps.Circle({
        strokeColor: "#059669",
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: "#059669",
        fillOpacity: 0.15,
        map: googleMap.current,
        center: { lat: zone.lat, lng: zone.lng },
        radius: zone.radius,
        clickable: false
      });
      circles.current.push(circle);
    });

    // Auto-fit if multiple zones exist
    if (zones.length > 1 && !center) {
      const bounds = new google.maps.LatLngBounds();
      zones.forEach(z => bounds.extend({ lat: z.lat, lng: z.lng }));
      googleMap.current.fitBounds(bounds, 50);
    } else if (center) {
      googleMap.current.setCenter(center);
      googleMap.current.setZoom(15);
    }
  }, [zones, mode, center, isApiLoaded]);

  return (
    <div ref={mapRef} className="w-full h-full flex items-center justify-center bg-gray-50">
      {!isApiLoaded && (
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
          <p className="text-sm font-bold text-gray-400 uppercase tracking-widest">Loading Guardian Map...</p>
        </div>
      )}
    </div>
  );
};

// --- Senior-Friendly UI Components ---

const RadarAnimation = () => (
  <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
    <div className="w-8 h-8 bg-[#2563EB] rounded-full relative z-10 shadow-lg border-2 border-white">
      <div className="absolute inset-0 bg-[#2563EB] rounded-full animate-ripple" />
      <div className="absolute inset-0 bg-[#2563EB] rounded-full animate-ripple [animation-delay:1.5s]" />
    </div>
  </div>
);

const SeniorMapHeader = ({ zones, onAdd, mapMode }: { zones: SafeZone[], onAdd: () => void, mapMode: MapViewMode }) => {
  return (
    <div 
      className="relative h-72 mx-6 rounded-[2.5rem] bg-[#FFFFFF] border border-[#E2E8F0] card-shadow overflow-hidden group transition-all"
    >
      <div className="absolute inset-0 z-0">
        <RealGoogleMap zones={zones.filter(z => z.enabled)} mode={mapMode} />
      </div>

      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <RadarAnimation />
      </div>
      
      <div className="absolute top-6 left-6 flex items-center gap-2 bg-[#2563EB] px-4 py-2 rounded-full shadow-xl z-10">
        <LocateFixed className="w-4 h-4 text-white" />
        <span className="text-[11px] font-extrabold text-white uppercase tracking-widest">Always Guarding</span>
      </div>
      
      <div 
        onClick={onAdd}
        className="absolute bottom-6 right-6 bg-[#FFFFFF] p-4 rounded-[1.5rem] shadow-2xl text-[#475569] border border-[#E2E8F0] z-10 cursor-pointer active:scale-90 transition-transform"
      >
        <Plus size={24} strokeWidth={4} />
      </div>
    </div>
  );
};

const SeniorZoneList = ({ zones, onEdit }: any) => (
  <div className="bg-[#FFFFFF] rounded-[2.5rem] card-shadow mx-6 overflow-hidden divide-y divide-[#F5F5F7] border border-[#E2E8F0]">
    {zones.map((zone: SafeZone) => (
      <div 
        key={zone.id} 
        onClick={() => onEdit(zone)}
        className="flex items-center gap-5 p-7 active:bg-[#F8FAFC] transition-colors cursor-pointer"
      >
        <div className={`p-4 rounded-[1.25rem] transition-all ${zone.enabled ? 'bg-[#F5F5F7] text-[#475569]' : 'bg-[#F5F5F7]/50 text-[#94A3B8]'}`}>
          {ZONE_ICONS[zone.type]}
        </div>
        <div className="flex-1 min-w-0">
          <h4 className={`font-extrabold text-xl truncate ${zone.enabled ? 'text-[#0F172A]' : 'text-[#64748B]'}`}>{zone.name}</h4>
          <p className="text-base text-[#475569] font-bold mt-0.5">
            {zone.enabled ? `${zone.radius}m Safe Zone` : 'Not Monitoring'}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className={`w-12 h-12 rounded-full flex items-center justify-center ${zone.enabled ? 'bg-[#F5F5F7] text-[#475569]' : 'bg-[#F5F5F7] text-[#94A3B8]'}`}>
            <ChevronRight className="w-6 h-6" strokeWidth={3} />
          </div>
        </div>
      </div>
    ))}
  </div>
);

const BigActionButton = ({ onClick, children, variant = 'primary', disabled = false }: any) => {
  const styles = variant === 'primary' 
    ? 'bg-[#FFFFFF] text-[#475569] border border-[#E2E8F0] card-shadow' 
    : 'bg-[#F5F5F7] text-[#475569] border border-transparent';
    
  return (
    <button 
      onClick={onClick}
      disabled={disabled}
      className={`w-full py-6 rounded-[2.25rem] flex items-center justify-center gap-4 active:bg-[#E2E8F0] transition-all font-black text-xl disabled:opacity-30 ${styles}`}
    >
      {children}
    </button>
  );
};

// --- Main App ---

const App = () => {
  const [screen, setScreen] = useState<ScreenMode>('home');
  const [mapMode, setMapMode] = useState<MapViewMode>('street');
  const [zones, setZones] = useState<SafeZone[]>([
    { id: '1', name: 'Home', type: 'home', lat: 51.5074, lng: -0.1278, radius: 250, enabled: true, notifyOnEnter: true, notifyOnExit: true },
    { id: '2', name: 'Park', type: 'other', lat: 51.5101, lng: -0.1342, radius: 150, enabled: true, notifyOnEnter: true, notifyOnExit: false },
  ]);
  const [selectedZoneId, setSelectedZoneId] = useState<string | null>(null);
  const [isAdding, setIsAdding] = useState(false);
  const [newZone, setNewZone] = useState<Partial<SafeZone>>({
    name: '', type: 'other', radius: 300, notifyOnEnter: true, notifyOnExit: true, enabled: true, lat: DEFAULT_CENTER.lat, lng: DEFAULT_CENTER.lng
  });

  const toggleMapMode = (e: React.MouseEvent) => {
    e.stopPropagation();
    const modes: MapViewMode[] = ['street', 'satellite', 'minimal'];
    const currentIndex = modes.indexOf(mapMode);
    setMapMode(modes[(currentIndex + 1) % modes.length]);
  };

  const handleSave = () => {
    if (isAdding) {
      setZones([...zones, { ...newZone, id: Date.now().toString(), enabled: true } as SafeZone]);
    } else {
      setZones(zones.map(z => z.id === selectedZoneId ? { ...z, ...newZone } : z));
    }
    setScreen('home');
  };

  const openEdit = (zone: SafeZone) => {
    setNewZone(zone);
    setSelectedZoneId(zone.id);
    setIsAdding(false);
    setScreen('add');
  };

  const openAdd = () => {
    setNewZone({ 
      name: '', 
      type: 'other', 
      radius: 300, 
      notifyOnEnter: true, 
      notifyOnExit: true, 
      enabled: true, 
      lat: DEFAULT_CENTER.lat, 
      lng: DEFAULT_CENTER.lng 
    });
    setIsAdding(true);
    setScreen('add');
  };

  const renderHome = () => (
    <div className="pb-40 animate-in fade-in duration-500 bg-[#FDFDFD] min-h-screen">
      <header className="px-8 pt-16 pb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-black text-[#0F172A] tracking-tight">Safe Zones</h1>
          <p className="text-[#475569] font-bold mt-1 text-lg">Guardian Angel is Monitoring</p>
        </div>
        <button onClick={() => setScreen('info')} className="p-4 bg-[#F5F5F7] rounded-[1.5rem] active:bg-[#E2E8F0] transition-colors">
          <Info className="w-7 h-7 text-[#475569]" strokeWidth={2.5} />
        </button>
      </header>

      <div className="space-y-12">
        <SeniorMapHeader zones={zones} onAdd={openAdd} mapMode={mapMode} />

        <div className="space-y-6">
          <div className="px-9 flex items-center justify-between">
            <h3 className="text-sm font-black text-[#64748B] uppercase tracking-[0.15em]">Trusted Places</h3>
            <div className="flex items-center gap-2 bg-[#F5F5F7] px-3 py-1 rounded-full border border-[#E2E8F0]">
              <div className="w-2 h-2 bg-[#059669] rounded-full animate-pulse" />
              <span className="text-[11px] font-black text-[#059669] uppercase">Protected</span>
            </div>
          </div>
          <SeniorZoneList zones={zones} onEdit={openEdit} />
        </div>

        <div className="px-8 pb-10">
          <div className="p-7 bg-[#FFFFFF] rounded-[2.5rem] border border-[#E2E8F0] card-shadow flex items-start gap-6">
            <div className="bg-[#2563EB] p-4 rounded-[1.25rem] text-white shadow-lg">
              <ShieldCheck size={32} />
            </div>
            <div>
              <p className="text-xl font-extrabold text-[#0F172A]">Family Only</p>
              <p className="text-lg text-[#475569] font-medium leading-snug mt-1">
                Your movements are private. Only boundary alerts go to your family.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 p-8 glass-overlay border-t border-[#E2E8F0] z-20">
        <BigActionButton onClick={openAdd}>
          <Plus size={26} strokeWidth={4} />
          Set New Safe Place
        </BigActionButton>
      </div>
    </div>
  );

  const renderAddEdit = () => (
    <div className="min-h-screen bg-[#FFFFFF] animate-in slide-in-from-bottom duration-400 flex flex-col">
      <div className="px-8 pt-16 pb-6 flex items-center justify-between sticky top-0 bg-[#FFFFFF]/95 backdrop-blur-md z-30 border-b border-[#F5F5F7]">
        <button onClick={() => setScreen('home')} className="p-4 bg-[#F5F5F7] rounded-full active:bg-[#E2E8F0]">
          <X className="w-6 h-6 text-[#0F172A]" strokeWidth={3} />
        </button>
        <h2 className="text-2xl font-black text-[#0F172A] tracking-tight">
          {isAdding ? 'Set Safe Place' : 'Modify Place'}
        </h2>
        <div className="w-12 h-12" />
      </div>

      <div className="flex-1 overflow-y-auto px-8 space-y-12 pt-8 pb-48">
        <div className="relative rounded-[2.5rem] border-2 border-[#E2E8F0] h-80 overflow-hidden card-shadow">
           <RealGoogleMap 
              zones={[{ ...newZone } as SafeZone]} 
              center={{ lat: newZone.lat!, lng: newZone.lng! }}
              mode={mapMode}
              onMapClick={(lat, lng) => setNewZone({ ...newZone, lat, lng })}
           />

           <div className="absolute inset-0 flex items-center justify-center pointer-events-none pb-14 z-10">
             <div className="relative">
               <div className={`p-5 rounded-[1.5rem] shadow-2xl border-4 ${mapMode === 'satellite' ? 'bg-[#1E293B] border-white/50 text-white' : 'bg-[#FFFFFF] border-[#E2E8F0] text-[#475569]'}`}>
                 {ZONE_ICONS[newZone.type as ZoneType]}
               </div>
               <div className={`w-2 h-7 blur-[1px] mx-auto rounded-full -mt-1 ${mapMode === 'satellite' ? 'bg-white/10' : 'bg-[#475569]/10'}`} />
             </div>
           </div>

           <button 
             onClick={toggleMapMode}
             className="absolute bottom-6 left-6 bg-[#FFFFFF] px-5 py-2.5 rounded-2xl flex items-center gap-3 border border-[#E2E8F0] shadow-md active:bg-[#F5F5F7] transition-colors z-20"
           >
             <MapIcon className="w-5 h-5 text-[#475569]" />
             <span className="text-xs font-black uppercase text-[#475569] tracking-wider">
               {mapMode === 'street' ? 'Standard' : mapMode === 'satellite' ? 'Satellite' : 'Minimal'}
             </span>
           </button>

           <div className="absolute top-4 right-4 bg-[#2563EB]/90 text-white px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest z-20">
             Tap map to move
           </div>
        </div>

        <div className="space-y-6">
           <div className="flex justify-between items-end px-2">
             <div>
                <label className="text-sm font-black text-[#64748B] uppercase tracking-[0.1em]">Zone Size</label>
                <p className="text-lg text-[#475569] font-bold">Safe coverage area</p>
             </div>
             <span className="text-5xl font-black text-[#059669] tracking-tighter tabular-nums">
               {newZone.radius}m
             </span>
           </div>
           <div className="bg-[#F5F5F7] p-6 rounded-[2.25rem] border border-[#E2E8F0] flex items-center px-8 shadow-inner">
             <input 
               type="range" min="100" max="1000" step="20"
               className="senior-slider w-full"
               value={newZone.radius}
               onChange={e => setNewZone({...newZone, radius: parseInt(e.target.value)})}
             />
           </div>
        </div>

        <div className="space-y-4">
           <label className="text-sm font-black text-[#64748B] uppercase tracking-[0.1em] px-2">Location Name</label>
           <input 
             type="text" placeholder="e.g. My Apartment"
             className="w-full p-8 bg-[#F5F5F7] border-2 border-[#E2E8F0] focus:border-[#475569] rounded-[2.25rem] font-extrabold text-2xl transition-all placeholder:text-[#94A3B8] outline-none"
             value={newZone.name}
             onChange={e => setNewZone({...newZone, name: e.target.value})}
           />
        </div>

        <div className="space-y-6">
           <label className="text-sm font-black text-[#64748B] uppercase tracking-[0.1em] px-2">Identify Place</label>
           <div className="flex flex-wrap gap-4">
             {(Object.keys(ZONE_ICONS) as ZoneType[]).map(type => (
               <button 
                 key={type}
                 onClick={() => setNewZone({...newZone, type})}
                 className={`flex flex-col items-center gap-3 p-6 rounded-[2.25rem] border-2 transition-all duration-200 min-w-[110px] ${
                   newZone.type === type 
                   ? 'bg-[#FFFFFF] border-[#475569] text-[#475569] shadow-xl scale-105' 
                   : 'bg-[#F5F5F7] border-transparent text-[#94A3B8]'
                 }`}
               >
                 {ZONE_ICONS[type]}
                 <span className="font-black text-sm capitalize tracking-tight">{type}</span>
               </button>
             ))}
           </div>
        </div>

        {!isAdding && (
          <div className="pt-10 border-t border-[#F5F5F7]">
             <button 
              onClick={() => {
                setZones(zones.filter(z => z.id !== selectedZoneId));
                setScreen('home');
              }}
              className="w-full py-6 rounded-[2.25rem] bg-[#FFFFFF] text-[#DC2626] font-black text-xl flex items-center justify-center gap-4 border-2 border-[#E2E8F0] active:bg-[#F5F5F7]"
             >
               <Trash2 size={24} strokeWidth={3} />
               Remove this place
             </button>
          </div>
        )}
      </div>

      <div className="fixed bottom-0 left-0 right-0 p-8 bg-[#FFFFFF] border-t border-[#F5F5F7] z-30">
        <BigActionButton onClick={handleSave} disabled={!newZone.name}>
          <Check size={32} strokeWidth={4} />
          Save Settings
        </BigActionButton>
      </div>
    </div>
  );

  const renderInfo = () => (
    <div className="min-h-screen bg-[#FDFDFD] text-[#0F172A] p-12 flex flex-col animate-in fade-in duration-500">
      <div className="flex justify-end">
        <button onClick={() => setScreen('home')} className="p-5 bg-[#F5F5F7] rounded-full active:bg-[#E2E8F0]">
          <X size={36} strokeWidth={3} />
        </button>
      </div>
      <div className="flex-1 mt-12 space-y-12">
        <div className="w-32 h-32 bg-[#F5F5F7] rounded-[3rem] flex items-center justify-center shadow-xl border border-[#E2E8F0]">
          <ShieldCheck size={64} strokeWidth={2} className="text-[#059669]" />
        </div>
        <div className="space-y-6">
          <h1 className="text-5xl font-black leading-tight tracking-tight">Private & Secure.</h1>
          <p className="text-2xl text-[#475569] font-semibold opacity-90 leading-relaxed">
            Guardian Angel only checks your position for alerts. Your private history is never saved.
          </p>
        </div>
        <div className="space-y-8 pt-8 border-t border-[#E2E8F0]">
           <div className="flex gap-6 items-center">
             <div className="w-5 h-5 bg-[#059669] rounded-full shrink-0 shadow-lg" />
             <p className="text-2xl font-bold">Trusted by your family.</p>
           </div>
           <div className="flex gap-6 items-center">
             <div className="w-5 h-5 bg-[#059669] rounded-full shrink-0 shadow-lg" />
             <p className="text-2xl font-bold">Privacy Guaranteed.</p>
           </div>
        </div>
      </div>
      <BigActionButton onClick={() => setScreen('home')}>
        I Am Ready
      </BigActionButton>
    </div>
  );

  return (
    <div className="max-w-screen min-h-screen relative bg-[#FDFDFD]">
      {screen === 'home' && renderHome()}
      {screen === 'add' && renderAddEdit()}
      {screen === 'info' && renderInfo()}
    </div>
  );
};

const rootElement = document.getElementById('root');
if (rootElement) {
  createRoot(rootElement).render(<App />);
}
