class_name RewardedAds
extends RefCounted
## Integración opcional de anuncios recompensados, encapsulada.
##
## La versión base NO incluye SDK de anuncios: `provider` es nulo y
## `is_available()` devuelve false, por lo que la interfaz no muestra el botón
## (no hay botones decorativos). Las vidas se recuperan esperando o con el
## desafío diario. Para integrar un SDK (p. ej. un plugin de Android), crear
## un objeto con los métodos `is_ready() -> bool` y
## `show_rewarded(on_done: Callable)` (on_done recibe `true` si el jugador
## vio el anuncio completo) y asignarlo con `RewardedAds.provider = ...`
## al iniciar el juego.

static var provider: Object = null


static func is_available() -> bool:
	return provider != null and provider.has_method("is_ready") and provider.is_ready()


## Muestra un anuncio y llama `on_reward` sólo si se completó.
static func show(on_reward: Callable) -> void:
	if not is_available():
		return
	provider.show_rewarded(func(completed: bool):
		if completed:
			on_reward.call())
