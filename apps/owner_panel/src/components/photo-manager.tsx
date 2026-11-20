'use client';

import { useState, useTransition } from 'react';
import { saveVenuePhotos } from '@/actions/venues';
import { FormMessage } from '@/components/form-message';
import type { ActionState } from '@/lib/action-state';
import { createClient } from '@/lib/supabase/client';
import { photoUrl } from '@/lib/storage';

const MAX_PHOTOS = 10;
const MAX_BYTES = 5 * 1024 * 1024;
const EXT_BY_TYPE: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

export function PhotoManager({
  venueId,
  initialPaths,
  initialCover,
}: {
  venueId: string;
  initialPaths: string[];
  initialCover: string | null;
}) {
  const [paths, setPaths] = useState(initialPaths);
  const [cover, setCover] = useState<string | null>(initialCover);
  const [state, setState] = useState<ActionState>(null);
  const [pending, startTransition] = useTransition();

  function persist(nextPaths: string[], nextCover: string | null, successMessage: string) {
    startTransition(async () => {
      const res = await saveVenuePhotos(venueId, nextCover, nextPaths);
      if (res?.ok) {
        setPaths(nextPaths);
        setCover(nextCover);
        setState({ ok: true, message: successMessage });
      } else {
        setState(res);
      }
    });
  }

  function onFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    const list = Array.from(files);
    if (paths.length + list.length > MAX_PHOTOS) {
      setState({ ok: false, message: `En fazla ${MAX_PHOTOS} fotoğraf yükleyebilirsin.` });
      return;
    }
    for (const f of list) {
      if (!EXT_BY_TYPE[f.type]) return setState({ ok: false, message: 'Yalnızca JPG, PNG veya WebP yükleyebilirsin.' });
      if (f.size > MAX_BYTES) return setState({ ok: false, message: 'Her fotoğraf en fazla 5 MB olabilir.' });
    }

    startTransition(async () => {
      const supabase = createClient();
      const uploaded: string[] = [];
      for (const f of list) {
        const path = `${venueId}/${crypto.randomUUID()}.${EXT_BY_TYPE[f.type]}`;
        const { error } = await supabase.storage.from('venue-photos').upload(path, f, { contentType: f.type, upsert: false });
        if (error) {
          setState({ ok: false, message: 'Fotoğraf yüklenemedi. Biraz sonra tekrar dene.' });
          return;
        }
        uploaded.push(path);
      }
      const nextPaths = [...paths, ...uploaded];
      const res = await saveVenuePhotos(venueId, cover ?? nextPaths[0] ?? null, nextPaths);
      if (res?.ok) {
        setPaths(nextPaths);
        setCover(cover ?? nextPaths[0] ?? null);
        setState({ ok: true, message: 'Fotoğraflar yüklendi.' });
      } else {
        setState(res);
      }
    });
  }

  function remove(path: string) {
    const nextPaths = paths.filter((p) => p !== path);
    const nextCover = cover === path ? (nextPaths[0] ?? null) : cover;
    startTransition(async () => {
      const res = await saveVenuePhotos(venueId, nextCover, nextPaths);
      if (!res?.ok) {
        setState(res);
        return;
      }
      await createClient().storage.from('venue-photos').remove([path]);
      setPaths(nextPaths);
      setCover(nextCover);
      setState({ ok: true, message: 'Fotoğraf silindi.' });
    });
  }

  return (
    <div className="space-y-4">
      {paths.length === 0 ? <p className="text-sm text-textSecondary">Henüz fotoğraf yok.</p> : null}
      <ul className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {paths.map((p) => (
          <li key={p} className="overflow-hidden rounded-xl border border-border">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={photoUrl(p)} alt="Tesis fotoğrafı" className="aspect-video w-full object-cover" />
            <div className="flex flex-wrap items-center gap-2 p-2">
              {cover === p ? (
                <span className="badge bg-accentSoft text-primary">Kapak</span>
              ) : (
                <button type="button" disabled={pending} className="btn-secondary btn-sm" onClick={() => persist(paths, p, 'Kapak fotoğrafı güncellendi.')}>
                  Kapak yap
                </button>
              )}
              <button type="button" disabled={pending} className="btn-secondary btn-sm text-danger" onClick={() => remove(p)}>
                Sil
              </button>
            </div>
          </li>
        ))}
      </ul>
      <div>
        <label htmlFor="photo-upload" className="label">Fotoğraf yükle (JPG, PNG, WebP · en fazla 5 MB)</label>
        <input
          id="photo-upload"
          type="file"
          multiple
          accept="image/jpeg,image/png,image/webp"
          disabled={pending}
          onChange={(e) => {
            onFiles(e.target.files);
            e.target.value = '';
          }}
          className="text-sm"
        />
      </div>
      {pending ? <p role="status" className="text-sm text-textSecondary">İşleniyor…</p> : null}
      <FormMessage state={state} />
    </div>
  );
}
