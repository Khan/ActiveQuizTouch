{TextLayer} = require 'TextLayer'

# Set this to true to cause many questions to be spawned when the level starts.
debugShouldSpawnManyQuestions = false

#==========================================
# Initial state 

points = 0
currentLevel = null # 1-indexed (for convenience, because it's shown to the user)
exitQuestionIndex = null # Tracks which question index is going to be the exit question in this level--it may not have been added yet.
setGameState = null # Defined later; working around Framer definition ordering issues.

levelRootLayer = new Layer
	width: Screen.width
	height: Screen.height
	backgroundColor: ""
	
clip = (value, min, max) ->
	Math.max(min, Math.min(max, value))

#==========================================
# Style Stuffz

# Color Palette

medGray = "rgba(216,216,216,1)"
lightGray = "rgba(227,229,230,1)"
darkGray = "rgba(98,101,105,1)"
correctColor = "rgba(116,207,112,1)"
incorrectColor = "rgba(255,132,130,1)"
selectColor = "rgba(157,243,255,1)" # TODO(andy): unused after redesign?
whiteColor = "white"
yellowColor = "yellow"
transparent = "rgba(0,0,0,0)"

questionBorderColorSelected = whiteColor
questionBorderColorUnselected = "rgba(250, 250, 250, 0.8)"

fontFamily = "ProximaNovaRegular"

customFontStyle = document.createElement("style")
customFontCSS = "@font-face{font-family:#{fontFamily};src:url(ProximaNova-Reg-webfont.ttf);}"
customFontStyle.appendChild(document.createTextNode(customFontCSS))
document.head.appendChild(customFontStyle)

background = new Layer
	width: Screen.width,
	height: Screen.height
background.style.background = "linear-gradient(to bottom, #031B3C, #5FA9B4)"
background.sendToBack()

# Sizes of things

questionWidthUnselected = 195 * 2
questionWidthSelected = 222 * 2
questionHeightUnselected = 55 * 2
questionHeightSelected = 61 * 2

questionBorderWidthUnselected = 1
questionBorderWidthSelected = 3 * 2

questionPromptSize = 48
questionNumberSpacing = 14*2

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

startingClockTimeInSeconds = 60

endTime = Infinity
pauseTime = null # When set, contains the remaining number of milliseconds before the game should end
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

pause = -> pauseTime = endTime - performance.now()
unpause = ->
	return if pauseTime == null
	endTime = performance.now() + pauseTime
	pauseTime = null

updateTimer = (timestamp) ->
	requestAnimationFrame updateTimer

	return if pauseTime != null
	
	newTime = Math.ceil((endTime - timestamp) / 1000)
	if newTime <= 0
		setGameState "gameOver"
		
	if newTime != lastTimeUpdate
		lastTimeUpdate = newTime
		timeDisplay.text = "Remaining: " + newTime + "s"

requestAnimationFrame updateTimer


addTime = (extraSeconds) ->
	endTime += extraSeconds * 1000

#==========================================
# Problem Generation

allOperators = [
	{label: "+", operation: (a, b) -> a + b}
	{label: "-", operation: (a, b) -> a - b}
	{label: "*", operation: (a, b) -> a * b}
]

generateProblem = (difficulty, level) ->
	maxOperatorIndex = Math.floor(clip(difficulty / 2 - 1, 0, 2))
	numberOfOperators = (Math.floor(difficulty / 2) % 3) + 1
	maxOperandValue = (Math.floor(difficulty / 6) * 10) + 10
	numberOfOperands = numberOfOperators + 1
	numbers = [0..(numberOfOperands - 1)].map -> Math.floor(Utils.randomNumber(0, maxOperandValue))
	operators = [0..(numberOfOperators - 1)].map -> Utils.randomChoice(allOperators[0..maxOperatorIndex])
	
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
	questionsRevealed: Utils.randomChoice([0, 1, 1, 2, 2, 2, 3])

#==========================================
# Game "board"

maximumNumberOfProblems = (levelNumber) ->
	# 1, 2, 5, 8, 13, 18, 26, ...
	return Math.ceil(levelNumber * levelNumber / 2)

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
setSelectedQuestion = (newSelectedQuestion, animated) -> 
	selectedQuestion?.setSelected false, animated
	selectedQuestion = newSelectedQuestion
	newSelectedQuestion?.setSelected true, animated
	noSelectionKeyboardOverlay?.setVisible (if newSelectedQuestion then false else true)
	
questions = []

addQuestion = (newQuestion, animated) ->
	if questions.length == exitQuestionIndex
		# That means we're about to add the end question! Neat!
		newQuestion.markAsExitQuestion()
		
	questions.unshift(newQuestion)
	newQuestion.x = Math.floor(Utils.randomNumber(56*2, 93*2))
	updateQuestionLayout animated
	
updateQuestionLayout = (animated) ->
	answeredQuestions = questions.filter (question) -> question.isAnswered
	unansweredQuestions = questions.filter (question) -> not question.isAnswered
	
	y = 66*2
	delay = 0
	for question in unansweredQuestions
		question.animate
			properties:
				y: y
			time: if animated then 0.2 else 0
			delay: delay
		y += questionHeightUnselected + questionNumberSpacing
		delay += 0.02
	for question in answeredQuestions
		question.animate
			properties:
				y: y
			time: if animated then 0.2 else 0
			delay: delay
		y += questionHeightUnselected + questionNumberSpacing
		delay += 0.02
			
	setTimeout(->
		questionScrollComponent.updateContent() # Resize the scrollable bounds of the question scroll component according to the new layout
	, (delay + 0.2) * 1000)

#==========================================
# Question Cells

createQuestion = (difficulty, level) ->
	question = new Layer
		parent: questionScrollComponent.content
		backgroundColor: ""
		width: questionWidthUnselected
		height: questionHeightUnselected
		
	questionBorder = new Layer
		parent: question
		borderColor: questionBorderColorUnselected
		borderRadius: questionHeightUnselected / 2
		borderWidth: questionBorderWidthUnselected
		shadowBlur: 22*2
		shadowSpread: 4*2
		width: question.width
		height: question.height
		backgroundColor: ""
		
	question.setSelected = (selected, animated) ->
		if selected
			time = if animated then 0.15 else 0
			questionBorder.animate
				properties:
					borderWidth: questionBorderWidthSelected
					borderColor: questionBorderColorSelected
					borderRadius: questionHeightSelected / 2
					width: questionWidthSelected
					height: questionHeightSelected
					x: -(questionWidthSelected - questionWidthUnselected) / 2
					y: -(questionHeightSelected - questionHeightUnselected) / 2
					shadowColor: whiteColor
				time: time
		else
			time = if animated then 0.1 else 0
			questionBorder.animate
				properties:
					borderWidth: questionBorderWidthUnselected
					borderColor: questionBorderColorUnselected
					borderRadius: questionHeightUnselected / 2
					width: questionWidthUnselected
					height: questionHeightUnselected
					x: 0
					y: 0
					shadowColor: "rgba(0,0,0,0)"
				time: time
		question.answerLayer.text = "" if not selected and not question.isAnswered
		
	question.onTap ->
		return if question.isAnswered
		
		setSelectedQuestion question, true
		question.updatePendingNumber
			number: null
			sign: 1
			
	question.problem = generateProblem(difficulty, level)
	
	question.isAnswered = false
	
	question.markAsExitQuestion = ->
		question.isExit = true
			
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
		height: questionHeightUnselected
		fontSize: questionPromptSize
		color: incorrectColor
		backgroundColor: transparent
		parent: question
		text: "foo"
	# this is dumb but if we don't do this then the answerLayer size is technically still 0 and we can't move its midpoint
	question.answerLayer.midY = question.height / 2
	question.answerLayer.text =  " " 
	question.answerBuffer = {number: null, sign: 1}
	
	rewardDebugLayer = new TextLayer
		parent: question
		x: 30
		y: 70
		autoSize: true
		color: "black"
	rewardDebugLayer.text = "#{question.problem.reward.count} #{if question.problem.reward.type == "points" then "points" else "time units"}; #{question.problem.questionsRevealed} question revealed; difficulty = #{difficulty}"
		
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
		question.answerLayer.color = medGray
		question.answerBuffer = {number: null, sign: 1}
		
	question.giveRewards = ->
		switch question.problem.reward.type
			when "points"
				setPoints points + question.problem.reward.count
			when "time"
				# Give 3 seconds per "time unit".
				addTime question.problem.reward.count * 3


	question.submit = ->
		return if question.isAnswered
		
		userAnswer = question.answerBuffer.number * question.answerBuffer.sign
		isCorrect = userAnswer == question.problem.answer
		if isCorrect
			question.isAnswered = true
			question.giveRewards()
			setSelectedQuestion null, true
			
			correctHighlightLayer = new Layer
				parent: question
				backgroundColor: correctColor
				width: question.width
				height: 0
				y: 0
				borderRadius: question.borderRadius
			correctHighlightLayer.placeBefore(selectionHighlightLayer)
			correctHighlightLayer.animate
				properties:
					height: question.height
				time: 0.2
			
			if question.isExit
				setGameState "levelComplete"
			else
				# Reveal new questions:
				isLastAvailableQuestion = questions.filter((question) -> not question.isAnswered).length == 0
				effectiveNumberOfQuestionsRevealed = clip(
					question.problem.questionsRevealed,
					if isLastAvailableQuestion then 1 else 0, 
					maximumNumberOfProblems(level) - questions.length
				)
				for questionNumber in [0...effectiveNumberOfQuestionsRevealed]
					# New question difficulty is based on previous question difficulty, but the difficulty level can only shift by 1 (either direction) each time, and it can never be more than 2 levels of difficult beyond the base level number.
					newDifficulty = clip(difficulty + Utils.randomChoice([-1, 0, 1]), level, level + 2)
					addQuestion createQuestion(newDifficulty, level), true
				updateQuestionLayout true
		else
			incorrectHighlightLayer = new Layer
				parent: question
				backgroundColor: incorrectColor
				width: question.width
				height: 0
				y: question.height
				borderRadius: question.borderRadius
			incorrectHighlightLayer.placeBefore(selectionHighlightLayer)
				
			incorrectHighlightLayerAnimation = new Animation
				layer: incorrectHighlightLayer
				time: 0.2
				properties:
					height: question.height
					y: 0
			 
			# After a little bit, reverse the animation.
			setTimeout(->
				incorrectHighlightLayerAnimation.reverse().start() 
			, 700) # in milliseconds
			incorrectHighlightLayerAnimation.start()
			
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
		fontFamily: fontFamily
		color: "black"
		autoSize: true
		text: text
	buttonLabel.midX = button.width / 2
	buttonLabel.midY = button.height / 2
	return button

#==========================================
# Level complete UI

levelCompleteLayer = new Layer
	width: Screen.width
	height: Screen.height
	visible: false
levelCompleteLabel = new TextLayer
	parent: levelCompleteLayer
	color: "white"
	y: 300
	autoSize: true
	fontFamily: fontFamily
	fontSize: 80

levelCompleteScoreLabel = new TextLayer
	parent: levelCompleteLayer
	color: "white"
	y: 500
	autoSize: true
	fontFamily: fontFamily
	fontSize: 48
	
nextLevelButton = createButton "Next level", ->
	currentLevel += 1
	setGameState "level"
nextLevelButton.parent = levelCompleteLayer
nextLevelButton.y = 700

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
	fontFamily: fontFamily
	fontSize: 80
gameOverLabel.midX = gameOverLayer.midX

gameOverScoreLabel = new TextLayer
	parent: gameOverLayer
	color: "white"
	y: 500
	autoSize: true
	fontFamily: fontFamily
	fontSize: 48
	
retryButton = createButton "Play again", ->
	setGameState "newGame"
retryButton.parent = gameOverLayer
retryButton.y = 700

#==========================================
# Game state

setGameState = (newGameState) ->
	return if newGameState == gameState
	
	switch newGameState
		when "newGame"
			currentLevel = 1
			endTime = performance.now() + startingClockTimeInSeconds * 1000
			setPoints 0
			setGameState "level"
			
		when "level"
			setSelectedQuestion null, false
		
			for question in questions
				question.destroy()
			questions = []
			
			levelRootLayer.visible = true
			levelCompleteLayer.visible = false
			gameOverLayer.visible = false
			
			exitQuestionIndex = Math.round(Utils.randomNumber(Math.floor(maximumNumberOfProblems(currentLevel) / 2), maximumNumberOfProblems(currentLevel) - 1))

			# We may want to add multiple questions at the start of a level in the future: this is where we'd do that!
			initialQuestion = createQuestion(currentLevel, currentLevel)
			addQuestion initialQuestion
			setSelectedQuestion initialQuestion, false
			
			if debugShouldSpawnManyQuestions
				addQuestion createQuestion(currentLevel, currentLevel) for _ in [0..5]
			
			unpause()

		when "levelComplete"
			pause()
			
			# Give rewards for all remaining unanswered questions.
			for question in questions
				if not question.isAnswered
					question.giveRewards()
		
			levelRootLayer.visible = false
			levelCompleteLayer.visible = true
			gameOverLayer.visible = false
			
			levelCompleteLabel.text = "Completed level " + currentLevel + "!"
			levelCompleteLabel.midX = levelCompleteLayer.midX

			levelCompleteScoreLabel.text = "Current score: " + points
			levelCompleteScoreLabel.midX = levelCompleteLayer.midX
			
		when "gameOver"
			levelRootLayer.visible = false
			levelCompleteLayer.visible = false
			gameOverLayer.visible = true
			
			gameOverScoreLabel.text = "Your score: " + points + " points"
			gameOverScoreLabel.midX = gameOverLayer.midX
	gameState = newGameState

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
			fontFamily: fontFamily
		
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
noop = (event) -> return
noSelectionKeyboardOverlay.setVisible = (isVisible) ->
	if isVisible
		noSelectionKeyboardOverlay.visible = true
	
	animationLengthInSeconds = 0.2
	noSelectionKeyboardOverlay?.animate
		properties:
			opacity: if isVisible then 1 else 0
		time: animationLengthInSeconds
	if not isVisible
		setTimeout(->
			noSelectionKeyboardOverlay.visible = false
		, animationLengthInSeconds * 1000)

noSelectionKeyboardOverlayLabel = new TextLayer
	parent: noSelectionKeyboardOverlay
	text: "Select a question"
	autoSize: true
	color: darkGray
	fontFamily: fontFamily
	fontSize: 48
noSelectionKeyboardOverlayLabel.midX = keyboard.midX
noSelectionKeyboardOverlayLabel.midY = keyboard.height / 2

setGameState "newGame"
