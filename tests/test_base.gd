extends RefCounted
## Base de pruebas: helpers de aserción.

var runner


func check(cond: bool, msg: String) -> bool:
	if not cond:
		runner.fail(msg)
	return cond


func eq(a, b, msg: String) -> bool:
	if a != b:
		runner.fail("%s (esperado %s, obtenido %s)" % [msg, str(b), str(a)])
		return false
	return true
