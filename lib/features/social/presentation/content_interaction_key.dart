/// Part P-058 scope: the family key for `contentInteractionProvider`
/// (this same folder). A Dart record — not a hand-rolled class with
/// manual `==`/`hashCode` — because records get structural equality
/// for free, which is exactly what a `NotifierProvider.family` arg
/// needs for correct provider caching (two calls with the same
/// `contentType`/`objectId` must resolve to the SAME provider
/// instance).
typedef ContentInteractionKey = ({String contentType, int objectId});