
export function initTracing(serviceName = 'trip-service') {
  
  try {
    import('@opentelemetry/sdk-node')
      .then(({ NodeSDK }) =>
        import('@opentelemetry/auto-instrumentations-node').then(
          ({ getNodeAutoInstrumentations }) => {
            const sdk = new NodeSDK({
              instrumentations: [getNodeAutoInstrumentations()],
            })
            sdk
              .start()
              .then(() =>
                console.log('OpenTelemetry initialized for', serviceName)
              )
              .catch(() => console.warn('OpenTelemetry start failed'))
          }
        )
      )
      .catch(() =>
        console.warn('OpenTelemetry packages not installed - tracing disabled')
      )
  } catch (err) {
    
    console.warn('Tracing not initialized (optional)')
  }
}
