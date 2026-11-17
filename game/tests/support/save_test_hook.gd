extends GutHookScript
## GUT pre-run hook (spec 010, plan D10): before any test, SaveManager gets a
## save store in memory and a quit action that does not quit, so no test ever
## touches the real saves or closes the runner.


func run() -> void:
	SaveTestSupport.reset()
