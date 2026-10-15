abstract interface class NormalizerService<TInput, TOutput> {
  TOutput normalize(TInput input);
}
