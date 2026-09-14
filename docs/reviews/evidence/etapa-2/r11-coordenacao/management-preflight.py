"""Read only Supabase configuration; print allowlisted flags, never credentials."""
import ctypes
from ctypes import wintypes
import json
import argparse
from pathlib import Path
from datetime import datetime, timezone
from urllib.request import Request, urlopen

class Credential(ctypes.Structure):
    _fields_ = [('Flags', wintypes.DWORD), ('Type', wintypes.DWORD),
                ('TargetName', wintypes.LPWSTR), ('Comment', wintypes.LPWSTR),
                ('LastWritten', wintypes.FILETIME), ('CredentialBlobSize', wintypes.DWORD),
                ('CredentialBlob', ctypes.POINTER(ctypes.c_byte)), ('Persist', wintypes.DWORD),
                ('AttributeCount', wintypes.DWORD), ('Attributes', ctypes.c_void_p),
                ('TargetAlias', wintypes.LPWSTR), ('UserName', wintypes.LPWSTR)]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).with_name('management-preflight.json'))
    args = parser.parse_args()
    pointer = ctypes.POINTER(Credential)()
    api = ctypes.WinDLL('Advapi32.dll')
    if not api.CredReadW('Supabase CLI:supabase', 1, 0, ctypes.byref(pointer)):
        raise RuntimeError('Supabase CLI credential unavailable')
    try:
        token = ctypes.string_at(pointer.contents.CredentialBlob, pointer.contents.CredentialBlobSize).decode('utf-8')
    finally:
        api.CredFree(pointer)
    result = {'at': datetime.now(timezone.utc).isoformat(), 'project': 'evvbomzejfijozbtgvpt'}
    for name, endpoint in [('backups', 'database/backups'), ('auth', 'config/auth')]:
        request = Request('https://api.supabase.com/v1/projects/evvbomzejfijozbtgvpt/'+endpoint,
                          headers={'Authorization': 'Bearer '+token})
        try:
            with urlopen(request, timeout=20) as response:
                body = json.load(response)
            if name == 'backups':
                result[name] = {k:body.get(k) for k in ('pitr_enabled','physical_backup_data','region')}
                result[name]['backup_count'] = len(body.get('backups',[]))
            else:
                result[name] = {k:body.get(k) for k in ('site_url','uri_allow_list','mailer_otp_exp','mailer_autoconfirm')}
                result[name]['custom_smtp_configured'] = bool(body.get('smtp_host'))
                result[name]['smtp_sender_configured'] = bool(body.get('smtp_admin_email'))
        except Exception as error:
            result[name] = {'error':type(error).__name__, 'http':getattr(error,'code',None)}
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
