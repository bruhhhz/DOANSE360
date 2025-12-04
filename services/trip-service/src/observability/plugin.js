
export default function observabilityMiddleware(req, res, next) {
  try {
    const incoming = req.headers['x-request-id'] || req.headers['x_request_id']
    req.requestId =
      incoming || `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
    req.requestStartTime = Date.now()
  } catch (e) {
    
  }

  res.on('finish', () => {
    try {
      const duration = Date.now() - (req.requestStartTime || Date.now())
      
      console.info(
        JSON.stringify({
          msg: 'http_request_complete',
          method: req.method,
          path: req.path,
          statusCode: res.statusCode,
          duration,
          requestId: req.requestId,
        })
      )
    } catch (e) {}
  })

  next()
}
