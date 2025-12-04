import jwt from 'jsonwebtoken';

export function verifyToken(req, res, next) {
  const auth = req.headers['authorization'];
  console.log('[auth] header:', auth);

  // Nếu không có token → tạo user giả
  if (!auth || !auth.startsWith('Bearer ')) {
    console.warn('⚠️ Không có token → tạo user giả để test nội bộ');
    req.user = { sub: req.body?.userId || 1, role: 'user' };
    console.log('[auth] fake user gán cho req.user =', req.user);
    return next();
  }

  try {
    const token = auth.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    console.log('[auth] decoded token =', decoded);
    next();
  } catch (err) {
    console.error('[auth] Lỗi verify token:', err);
    return res.status(403).json({ message: 'Token không hợp lệ' });
  }
}
