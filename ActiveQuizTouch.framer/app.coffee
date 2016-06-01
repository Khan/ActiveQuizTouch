{TextLayer} = require 'TextLayer'

points = 0
currentLevel = 4

#==========================================
# Points

pointsDisplay = new TextLayer
	color: "white"
	fontSize: 40
	x: 30
	y: 30
updatePoints = (newPoints) ->
	pointsDisplay.text = "Points: " + newPoints
	points = newPoints
updatePoints(0)

#==========================================
# Timer

endTime = performance.now() + 60000
lastTimeUpdate = 0

timeDisplay = new TextLayer
	color: "white"
	fontSize: 40
	width: 300
	x: Screen.width - 330
	y: 30
	textAlign: "right"
	text: "Remaining: 3s"
	
updateTimer = (timestamp) ->
	newTime = Math.ceil((endTime - timestamp) / 1000)
	if newTime != lastTimeUpdate
		lastTimeUpdate = newTime
		timeDisplay.text = "Remaining: " + newTime + "s"
	requestAnimationFrame updateTimer
#requestAnimationFrame updateTimer

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
	numbers = [0..numberOfOperands].map -> Math.floor(Utils.randomNumber(0, maxOperandValue))
	operators = [0..numberOfOperators].map -> Utils.randomChoice(operators[0..maxOperatorIndex])
	
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
	y: 110
	width: Screen.width
	height: Screen.height - 110
	scrollHorizontal: false
	contentInset:
		top: 0
		bottom: keyboardHeight

selectedQuestion = null
questionNumberHeight = 80
questionNumberSpacing = 20

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
		else
			question.y = y

#==========================================
# Question Cells

createQuestion = (difficulty, level) ->
	question = new Layer
		parent: questionScrollComponent.content
		backgroundColor: "white"
		width: Screen.width
		height: questionNumberHeight
	question.setSelected = (selected) ->
		question.backgroundColor = if question.isAnswered
			"green"
		else if selected
			"blue"
		else
			"white"
		question.answerLayer.text = "" if not selected and not question.isAnswered
	question.onTap ->
		return if question.isAnswered
		
		selectedQuestion.setSelected false if selectedQuestion
		selectedQuestion = question
		question.setSelected true
		
		question.updatePendingNumber
			number: null
			sign: 1
			
	question.problem = generateProblem(difficulty, level)
	
	question.isAnswered = false
			
	questionPrompt = new TextLayer
		x: 30
		autoSize: true
		fontSize: 48
		color: "black"
		parent: question
		text: question.problem.label
		
	question.answerLayer = new TextLayer
		x: 400
		width: 304
		height: questionNumberHeight
		fontSize: 48
		color: "red"
		backgroundColor: "yellow"
		parent: question
		text: ""
		
	question.answerBuffer =
		number: null
		sign: 1
		
	question.updatePendingNumber = (newAnswerBuffer) ->
		question.answerBuffer = newAnswerBuffer
		if newAnswerBuffer.number == 0
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "0" else "-0"
		else if newAnswerBuffer.number == null
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "" else "-"
		else
			question.answerLayer.text = newAnswerBuffer.number * newAnswerBuffer.sign

	question.submit = ->
		return if question.isAnswered
		
		userAnswer = question.answerBuffer.number * question.answerBuffer.sign
		isCorrect = userAnswer == question.problem.answer
		if isCorrect
			question.isAnswered = true
			switch question.problem.reward.type
				when "points"
					updatePoints points + question.problem.reward.count
				when "time"
					addTime question.problem.reward.count
			
			question.setSelected false
			
			addQuestion createQuestion(difficulty, level), true for [0...question.problem.questionsRevealed]
		else
			oldColor = question.backgroundColor
			question.backgroundColor = "red"
			question.animate
				properties:
					backgroundColor: oldColor
				time: 0.5
		
	return question	

#==========================================
# Game state

for questionNumber in [0..5]
	question = createQuestion(currentLevel + Utils.randomChoice([0, 1, 2]), currentLevel)
	addQuestion(question)

#==========================================
# Answer Input

updatePendingNumber = (updateFunction) ->
	selectedQuestion.updatePendingNumber updateFunction(selectedQuestion.answerBuffer)

#==========================================
# Keyboard

keyboardHeight = 432
keyboard = new Layer
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
		if row == 3 and column > 0
			# These keys are "eaten" by the big 0 and submit keys
			continue
		
		key = new Layer
			width: keyWidth - keySpacing
			height: keyHeight - keySpacing
			x: column * keyWidth
			y: row * keyHeight
			parent: keyboard
		key.states.add
			highlight:
				backgroundColor: "rgba(134,255,242,1)"
			normal:
				if column == 3
					backgroundColor: "rgba(227,229,230,1)"
				else 
					backgroundColor: "rgba(216,216,216,1)"
		key.onTouchStart (event, layer) ->
			layer.states.switch "highlight", time: 0.1, curve: "easeout"
			
		unhighlight = (event, layer) ->
			layer.states.switch "normal", time: 0.3, curve: "easeout"
		key.states.switchInstant "normal"
		
		keyLabel = new TextLayer
			color: "rgba(98,101,105,1)"
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
		else if column == 3 && row == 1
			# Plus/minus
			keyLabel.text = "+/–"
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					number: answerBuffer.number
					sign: answerBuffer.sign * -1
				unhighlight event, layer
		else if column == 3 && row == 2
			# Submit
			keyLabel.text = "Submit"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				selectedQuestion.submit()
				unhighlight event, layer
		else if column == 0 && row == 3
			# Extra-wide zero key
			keyLabel.text = "0"
			key.onTouchEnd (event, layer) ->
				appendDigit 0
				unhighlight event, layer
			key.width = keyWidth * 3 - keySpacing
			
		keyLabel.center()

questionScrollComponent.height -= keyboardHeight