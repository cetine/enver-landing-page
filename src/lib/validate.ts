export function validateContact(data: { name: string; email: string; message: string }) {
  const errors: Partial<Record<'name' | 'email' | 'message', string>> = {};
  if (!data.name.trim()) errors.name = 'required';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) errors.email = 'invalid';
  if (data.message.trim().length < 5) errors.message = 'required';
  return { ok: Object.keys(errors).length === 0, errors };
}
