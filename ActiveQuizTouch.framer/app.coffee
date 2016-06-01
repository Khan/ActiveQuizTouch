{TextLayer} = require 'TextLayer'

points = 0
currentLevel = 4
startingClockTimeInSeconds = 60

setGameState = null # Defined later; working around Framer definition ordering issues.
levelRootLayer = new Layer
	width: Screen.width
	height: Screen.height

#==========================================
# Color Palette

medGray = "rgba(216,216,216,1)"
lightGray = "rgba(227,229,230,1)"
darkGray = "rgba(98,101,105,1)"
correctColor = "rgba(116,207,112,1)"
incorrectColor = "rgba(255,132,130,1)"
selectColor = "rgba(157,243,255,1)"
whiteColor = "white"
yellowColor = "yellow"

questionPromptSize = 48

#==========================================
# Points

pointsDisplay = new TextLayer
	parent: levelRootLayer
	color: whiteColor
	fontSize: 40
	x: 30
	y: 30
setPoints = (newPoints) ->
	pointsDisplay.text = "Points: " + newPoints
	points = newPoints
setPoints(0)

#==========================================
# Timer

endTime = Infinity
lastTimeUpdate = 0

timeDisplay = new TextLayer
	parent: levelRootLayer
	color: whiteColor
	fontSize: 40
	width: 300
	x: Screen.width - 330
	y: 30
	textAlign: "right"
	text: "Remaining: 3s"
		
updateTimer = (timestamp) ->
	newTime = Math.ceil((endTime - timestamp) / 1000)
	if newTime <= 0
		setGameState "gameOver"
		
	if newTime != lastTimeUpdate
		lastTimeUpdate = newTime
		timeDisplay.text = "Remaining: " + newTime + "s"
	requestAnimationFrame updateTimer

# requestAnimationFrame updateTimer


addTime = (extraSeconds) ->
	endTime += extraSeconds * 1000

#==========================================
# Problem Generation

operators = [
	{label: "+", operation: (a, b) -> a + b}
	{label: "-", operation: (a, b) -> a - b}
	{label: "*", operation: (a, b) -> a * b}
]

generateProblem = (difficulty, level) ->
	maxOperatorIndex = Math.floor(Math.min(difficulty / 2, 2))
	numberOfOperators = (Math.floor(difficulty / 2) % 3) + 1
	maxOperandValue = (Math.floor(difficulty / 6) * 10) + 10
	numberOfOperands = numberOfOperators + 1
	numbers = [0..(numberOfOperands - 1)].map -> Math.floor(Utils.randomNumber(0, maxOperandValue))
	operators = [0..(numberOfOperators - 1)].map -> Utils.randomChoice(operators[0..maxOperatorIndex])
	
	label = ""
	answer = 0
	for operatorIndex in [0..(numberOfOperators - 1)]
		label += numbers[operatorIndex] + " " + operators[operatorIndex].label + " "
	label += numbers[numberOfOperators]
	
	label: label
	answer: eval(label) # "cleverly" avoiding implementing order-of-operations
	reward:
		count: (difficulty - level) + 1
		type: if Math.random(1) > 0.33 then "points" else "time"
	questionsRevealed: Utils.randomChoice([0, 0, 1, 1, 1, 2, 3])

#==========================================
# Game "board"

questionScrollComponent = new ScrollComponent
	parent: levelRootLayer
	y: 110
	width: Screen.width
	height: Screen.height - 110
	scrollHorizontal: false
	contentInset:
		top: 0
		bottom: keyboardHeight

noSelectionKeyboardOverlay = null # Assigned later, in keyboard section. Annoying that Framer won't let you reference functions top-level variables that are defined later in the file.

selectedQuestion = null
setSelectedQuestion = (newSelectedQuestion) -> 
	selectedQuestion?.setSelected false
	selectedQuestion = newSelectedQuestion
	newSelectedQuestion?.setSelected true
	
	noSelectionKeyboardOverlay.animate
		properties:
			opacity: if newSelectedQuestion then 0 else 1
		time: 0.2

questionNumberHeight = 100
questionNumberSpacing = 2

questions = []

addQuestion = (newQuestion, animate) ->
	questions.unshift(newQuestion)
	
	for questionIndex in [0..(questions.length - 1)]
		y = questionIndex * (questionNumberHeight + questionNumberSpacing)
		question = questions[questionIndex]
		if animate
			question.animate
				properties:
					y: y
				time: 0.2
				curve:"spring(400,15,5)"
		else
			question.y = y

#==========================================
# Question Cells

createQuestion = (difficulty, level) ->
	question = new Layer
		parent: questionScrollComponent.content
		backgroundColor: whiteColor
		width: Screen.width
		height: questionNumberHeight
	question.setSelected = (selected) ->
		
		if question.isAnswered
			question.backgroundColor = correctColor
			question.answerLayer.backgroundColor = correctColor
		else if selected
			question.backgroundColor = selectColor
			question.answerLayer.backgroundColor = yellowColor
		else
			question.backgroundColor = whiteColor
			question.answerLayer.backgroundColor = whiteColor
		
		question.answerLayer.text = "" if not selected and not question.isAnswered
	question.onTap ->
		return if question.isAnswered
			
		setSelectedQuestion question	
		question.updatePendingNumber
			number: null
			sign: 1
			
# 		for questionNumber in [0...question.problem.questionsRevealed]
# 				addQuestion createQuestion(difficulty, level), true
			
	question.problem = generateProblem(difficulty, level)
	
	question.isAnswered = false
			
	questionPrompt = new TextLayer
		x: 30
		autoSize: true
		fontSize: questionPromptSize
		color: darkGray
		parent: question
		text: question.problem.label
	questionPrompt.midY = question.height / 2
		
	question.answerLayer = new TextLayer
		x: 400
		width: 304
		autoSize: true
		height: questionNumberHeight
		fontSize: questionPromptSize
		color: incorrectColor
		backgroundColor: whiteColor
		parent: question
		text: "foo"
	# this is dumb but if we don't do this then the answerLayer size is technically still 0 and we can't move its midpoint
	question.answerLayer.midY = question.height / 2
	question.answerLayer.text =  " " 
	question.answerBuffer = {number: null, sign: 1}
		
	question.updatePendingNumber = (newAnswerBuffer) ->
		question.answerBuffer = newAnswerBuffer
		question.answerLayer.color = darkGray
		if newAnswerBuffer.number == 0
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "0" else "-0"
		else if newAnswerBuffer.number == null
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "" else "-"
		else
			question.answerLayer.text = newAnswerBuffer.number * newAnswerBuffer.sign
			
	question.ghostifyAnswer = ->
		question.answerLayer.color = "#ccc"
		question.answerBuffer = {number: null, sign: 1}

	question.submit = ->
		return if question.isAnswered
		
		userAnswer = question.answerBuffer.number * question.answerBuffer.sign
		isCorrect = userAnswer == question.problem.answer
		if isCorrect
			question.isAnswered = true
			switch question.problem.reward.type
				when "points"
					setPoints points + question.problem.reward.count
				when "time"
					addTime question.problem.reward.count
			
			setSelectedQuestion null
			
			for questionNumber in [0...question.problem.questionsRevealed]
				addQuestion createQuestion(difficulty, level), true
				
		else
			oldColor = question.backgroundColor
			question.backgroundColor = incorrectColor
			question.animate
				properties:
					backgroundColor: oldColor
				delay: 0.75
				time: 2.0
			question.ghostifyAnswer()
		
	return question	

#==========================================
# UI button

createButton = (text, action) ->
	button = new Layer
		width: Screen.width
		height: 100
	button.states.add
		normal:
			backgroundColor: medGray
		highlight:
			backgroundColor: selectColor
	button.states.switchInstant "normal"
	button.onTouchStart ->
		button.states.switch "highlight", time: 0.1, curve: "easeout"
	button.onTouchEnd ->
		button.states.switch "normal", time: 0.3, curve: "easeout"
		action()
			
	buttonLabel = new TextLayer
		parent: button
		fontSize: 48
		fontFamily: "Proxima Nova"
		color: "black"
		autoSize: true
		text: text
	buttonLabel.midX = button.width / 2
	buttonLabel.midY = button.height / 2
	return button

#==========================================
# Game over UI

gameOverLayer = new Layer
	width: Screen.width
	height: Screen.height
	visible: false
gameOverLabel = new TextLayer
	parent: gameOverLayer
	color: "white"
	y: 300
	autoSize: true
	text: "Game Over!"
	fontFamily: "Proxima Nova"
	fontSize: 80
gameOverLabel.midX = gameOverLayer.midX

gameOverScoreLabel = new TextLayer
	parent: gameOverLayer
	color: "white"
	y: 500
	autoSize: true
	fontFamily: "Proxima Nova"
	fontSize: 48
	gameOverLabel.midX = gameOverLayer.midX
	
retryButton = createButton "Play again", ->
	setGameState "reset"
retryButton.parent = gameOverLayer
retryButton.y = 700

#==========================================
# Game state

setGameState = (newGameState) ->
	return if newGameState == gameState
	
	switch newGameState
		when "reset"
			for question in questions
				question.destroy()
			questions = []
			
			levelRootLayer.visible = true
			gameOverLayer.visible = false

			# Start the clock at 60 seconds.
			endTime = performance.now() + startingClockTimeInSeconds * 1000
			setPoints(0)
			for questionNumber in [0..5]
				question = createQuestion(currentLevel + Utils.randomChoice([0, 1, 2]), currentLevel)
				addQuestion(question)
			
		when "gameOver"
			levelRootLayer.visible = false
			gameOverLayer.visible = true
			gameOverScoreLabel.text = "Your score: " + points + " points"
			gameOverScoreLabel.midX = gameOverLayer.midX
	gameState = newGameState

setGameState "reset"

#==========================================
# Answer Input

updatePendingNumber = (updateFunction) ->
	selectedQuestion.updatePendingNumber updateFunction(selectedQuestion.answerBuffer)

#==========================================
# Keyboard

keyboardHeight = 432
keyboard = new Layer
	parent: levelRootLayer
	y: Screen.height - keyboardHeight
	width: Screen.width
	height: keyboardHeight
	backgroundColor: ""

keyWidth = Screen.width / 4
keyHeight = keyboardHeight / 4
keySpacing = 2

appendDigit = (digit) ->
	updatePendingNumber (answerBuffer) ->
		number: answerBuffer.number * 10 + digit
		sign: answerBuffer.sign
		
for column in [0..3]
	for row in [0..3]
		if (row == 3 and column > 1) or (row == 1 and column == 3)
			# These keys are "eaten" by the big 0, backspace, and submit keys
			continue
		
		key = new Layer
			width: keyWidth - keySpacing
			height: keyHeight - keySpacing
			x: column * keyWidth
			y: row * keyHeight
			parent: keyboard
		key.states.add
			highlight:
				backgroundColor: selectColor
			normal:
				if column == 3
					backgroundColor: lightGray
				else 
					backgroundColor: medGray
		key.onTouchStart (event, layer) ->
			layer.states.switch "highlight", time: 0.1, curve: "easeout"
			
		unhighlight = (event, layer) ->
			layer.states.switch "normal", time: 0.3, curve: "easeout"
		key.states.switchInstant "normal"
		
		keyLabel = new TextLayer
			color: darkGray
			parent: key
			autoSize: true
			fontSize: 48
			fontFamily: "Proxima Nova"
		
		if column < 3 && row < 3
			do (digit = row * 3 + column + 1) ->
				keyLabel.text = digit
				key.onTouchEnd (event, layer) ->
					appendDigit digit
					unhighlight event, layer
		else if column == 3 && row == 0
			# Backspace
			keyLabel.text = "bspace"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					if answerBuffer.number > 0
						newNumber = Math.trunc(answerBuffer.number / 10)
						
						# If we'd be going from e.g. "9" to "0", go to a blank field instead.
						number: if newNumber > 0 then newNumber else null
						sign: answerBuffer.sign
					else if answerBuffer.number == 0
						# There's an explicitly-typed zero, which we'll now remove (but we'll leave a negative sign if there is one).
						{ number: null, sign: answerBuffer.sign }
					else
						# If there's no number, just remove the negative.
						{ number: null, sign: 1 }
				unhighlight event, layer
		else if column == 3 && row == 2
			# Submit
			keyLabel.text = "Submit"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				selectedQuestion.submit()
				unhighlight event, layer
		else if column == 0 && row == 3
			# Plus/minus
			keyLabel.text = "+/–"
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					number: answerBuffer.number
					sign: answerBuffer.sign * -1
				unhighlight event, layer
		else if column == 1 && row == 3
			# Extra-wide zero key
			keyLabel.text = "0"
			key.onTouchEnd (event, layer) ->
				appendDigit 0
				unhighlight event, layer
			key.width = keyWidth * 2 - keySpacing
			
		keyLabel.center()

questionScrollComponent.height -= keyboardHeight

noSelectionKeyboardOverlay = new Layer
	parent: levelRootLayer
	width: keyboard.width
	height: keyboard.height
	x: keyboard.x
	y: keyboard.y
	backgroundColor: "rgba(216,216,216,1)"
newSelectionKeyboardOverlayLabel = new TextLayer
	parent: noSelectionKeyboardOverlay
	text: "Select a question"
	autoSize: true
	color: darkGray
	fontFamily: "Proxima Nova"
	fontSize: 48
newSelectionKeyboardOverlayLabel.midX = keyboard.midX
newSelectionKeyboardOverlayLabel.midY = keyboard.height / 2
