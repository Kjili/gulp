-- Gulp
--
-- Copyright (C) 2018  Annemarie Mattmann
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local conf = {
	world = {
		w = 1920/2,
		h = 800,
	},
	cakeImgSize = 64,
	gulpImgSize = 960,
	poopImgSize = 64,
	gulpMinSize = 10,
	gulpMaxSize = 2
}

local gulpState = {
	size = conf.gulpMinSize,
	speed = {x=0, y=0},
	pos = {x=conf.world.h/2, y=conf.world.h-70},
	activeQuad = 0,
	eating = -1,
	foodCount = 0,
	exploding = -1,
	poop = false,
	poopCount = 2
}

local cakeState = {
	activeCakes = {},
	cakeSpeed = 0.5,
	cakeCount = 0,
	cakeBonus = 200
}

local eatingAnimation = {
	quadIndices = {[0]=3, 4, 3, 4, 5},
	duration = 0.2,
	currentTime = 0
}

local poopAnimation = {
	quad = 1,
	duration = 0.2,
	currentTime = 0
}

local explodingAnimation = {
	quadIndices = {[0]=6, 7, 6, 7, 8},
	duration = 0.1,
	currentTime = 0
}

local player = {
	bestTime = 0,
	lastTime = 0
}

local activePoops = {}

function restart()
	gulpState.size = conf.gulpMinSize
	gulpState.speed = {x=0, y=0}
	gulpState.pos = {x=conf.world.h/2, y=conf.world.h-70}
	gulpState.activeQuad = 0
	gulpState.eating = -1
	gulpState.foodCount = 0
	gulpState.exploding = -1
	gulpState.poop = false
	gulpState.poopCount = 2
	activePoops = {}
	cakeState.activeCakes = {}
	cakeState.cakeSpeed = 0.5
	cakeState.cakeCount = 0
	eatingAnimation.currentTime = 0
	explodingAnimation.currentTime = 0
	gameOver = false
	startTime = love.timer.getTime()
end

function love.load()
	-- set window properties
	love.window.setTitle("Gulp")
	love.window.setMode(conf.world.w, conf.world.h, {resizable=false, vsync=false})

	-- set graphics properties
	--love.graphics.setDefaultFilter("nearest", "nearest") -- avoid blurry scaling

	-- load images
	cakeSprite = love.graphics.newImage("assets/cake.png")
	cakeQuads = {}
	for i = 0, cakeSprite:getWidth()/conf.cakeImgSize do
		cakeQuads[i] = love.graphics.newQuad(i*conf.cakeImgSize, 0, conf.cakeImgSize, conf.cakeImgSize, cakeSprite:getDimensions())
	end
	gulpSprite = love.graphics.newImage("assets/gulp.png")
	gulpQuads = {}
	for i = 0, gulpSprite:getWidth()/conf.gulpImgSize do
		gulpQuads[i] = love.graphics.newQuad(i*conf.gulpImgSize, 0, conf.gulpImgSize, conf.gulpImgSize, gulpSprite:getDimensions())
	end
	poopImg = love.graphics.newImage("assets/poop.png")

	gameOver = false
	startTime = love.timer.getTime()

	-- change default font size
	font = love.graphics.newFont(24)
	love.graphics.setFont(font)

	-- play music
	gulpSound = love.audio.newSource("assets/gulp.ogg", "static")
	nomSound = love.audio.newSource("assets/nom.ogg", "static")
	poopSound = love.audio.newSource("assets/poop.ogg", "static")
	explodeSound = love.audio.newSource("assets/explode.ogg", "static")

	--background = love.audio.newSource("assets/background.ogg", "stream")
	--background:setLooping(true)
	--love.audio.play(background)
end

function love.update(dt)
	--love.audio.play(sound)
	if gameOver or gulpState.exploding >= #explodingAnimation.quadIndices then
		gameOver = true
		return
	end

	-- generate cakes
	if love.math.random() < 0.01 then
		table.insert(cakeState.activeCakes, {quad=cakeQuads[love.math.random(0, 1)], x=love.math.random(0, conf.world.w - conf.cakeImgSize), y=70, alive=true})
	end

	spotCake = false
	eatCake = false

	-- move player
	gulpState.pos.x = gulpState.speed.x * dt + gulpState.pos.x
	if gulpState.pos.x < 0 then
		gulpState.speed.x = 0
		gulpState.pos.x = 0
	end
	if gulpState.pos.x > conf.world.w - conf.gulpImgSize/gulpState.size then
		gulpState.speed.x = 0
		gulpState.pos.x = conf.world.w - conf.gulpImgSize/gulpState.size
	end
	-- update y pos
	gulpState.pos.y = conf.world.h-70-conf.gulpImgSize/gulpState.size

	for key, cake in pairs(cakeState.activeCakes) do
		-- move cakes
		cake.y = cake.y + cakeState.cakeSpeed

		-- check cake coming
		if math.abs(gulpState.pos.x - cake.x) < conf.gulpImgSize/gulpState.size/2 and gulpState.pos.y - cake.y < 100 then
			spotCake = true
		end

		-- check cake "collision"
		if math.abs(gulpState.pos.x - cake.x) < conf.gulpImgSize/gulpState.size/2 and gulpState.pos.y - cake.y < 5 then
			eatCake = true
			cakeState.activeCakes[key] = nil
		end

		-- delete cakes moving out of the world
		if cake.y > conf.world.h then
			cakeState.cakeCount = cakeState.cakeCount + 1
			cakeState.activeCakes[key] = nil
		end
	end

	-- return to normal if eating animation is over
	if gulpState.eating == #eatingAnimation.quadIndices then
		gulpState.foodCount = gulpState.foodCount + 1
		gulpState.eating = -1
	end
	-- grow if eaten enough
	if gulpState.foodCount >= (conf.gulpMinSize + 1) - gulpState.size then
		gulpState.size = gulpState.size - 1
		gulpState.foodCount = 0
		gulpState.pos.x = gulpState.pos.x - math.abs(conf.gulpImgSize/(gulpState.size + 1) - conf.gulpImgSize/gulpState.size)/2
	end
	-- gain a poop for enough cakes passed
	if cakeState.cakeCount >= cakeState.cakeBonus then
		gulpState.poopCount = gulpState.poopCount + 1
		cakeState.cakeCount = 0
	end

	-- exploding animation
	if gulpState.exploding > -1 then
		explodingAnimation.currentTime = explodingAnimation.currentTime + dt
		if explodingAnimation.currentTime >= explodingAnimation.duration then
			gulpState.exploding = gulpState.exploding + 1
			explodingAnimation.currentTime = 0
		end
		gulpState.activeQuad = explodingAnimation.quadIndices[gulpState.exploding]
	-- poop animation
	elseif gulpState.poop then
		poopAnimation.currentTime = poopAnimation.currentTime + dt
		if poopAnimation.currentTime >= poopAnimation.duration then
			love.audio.play(poopSound)
			gulpState.poopCount = gulpState.poopCount - 1
			poopAnimation.currentTime = 0
			gulpState.foodCount = 0
			gulpState.size = gulpState.size + 1
			gulpState.pos.x = gulpState.pos.x + math.abs(conf.gulpImgSize/(gulpState.size - 1) - conf.gulpImgSize/gulpState.size)/2
			table.insert(activePoops, gulpState.pos.x)
			gulpState.poop = false
		end
		gulpState.activeQuad = poopAnimation.quad
	-- start eating
	elseif eatCake and gulpState.eating < 0 then
		love.audio.play(nomSound)
		gulpState.eating = gulpState.eating + 1
		gulpState.activeQuad = eatingAnimation.quadIndices[gulpState.eating]
	-- eating animation
	elseif gulpState.eating > -1 then
		eatingAnimation.currentTime = eatingAnimation.currentTime + dt
		if eatingAnimation.currentTime >= eatingAnimation.duration then
			gulpState.eating = gulpState.eating + 1
			eatingAnimation.currentTime = 0
		end
		gulpState.activeQuad = eatingAnimation.quadIndices[gulpState.eating]
	-- spot cake
	elseif spotCake then
		love.audio.play(gulpSound)
		gulpState.activeQuad = 2
	else
		gulpState.activeQuad = 0
	end

	-- explode
	if gulpState.size <= conf.gulpMaxSize and gulpState.exploding < 0 then
		love.audio.play(explodeSound)
		gulpState.exploding = gulpState.exploding + 1
		gulpState.activeQuad = explodingAnimation.quadIndices[gulpState.exploding]
		endTime = love.timer.getTime() - startTime
		player.bestTime = math.max(endTime, player.bestTime)
	end

end

function love.draw()
	-- header
	love.graphics.draw(poopImg, 10, 0)
	love.graphics.print(tostring(gulpState.poopCount), math.floor(conf.poopImgSize/2), math.floor(conf.poopImgSize/3))
	if not gameOver then
		love.graphics.printf(string.format("Time: %.2f", love.timer.getTime() - startTime), 0, 0, conf.world.w, "center")
	else
		love.graphics.printf(string.format("Time: %.2f", endTime), 0, 0, conf.world.w, "center")
	end
	love.graphics.printf(string.format("Eaten: %i of %i", gulpState.foodCount, (conf.gulpMinSize + 1) - gulpState.size), 0, 0, conf.world.w-10, "right")
	-- game elements
	love.graphics.draw(gulpSprite, gulpQuads[gulpState.activeQuad], gulpState.pos.x, gulpState.pos.y, 0, 1/gulpState.size, 1/gulpState.size)
	for key, cake in pairs(cakeState.activeCakes) do
		love.graphics.draw(cakeSprite, cake.quad, cake.x, cake.y)
	end
	for key, xPoop in pairs(activePoops) do
		love.graphics.draw(poopImg, xPoop + conf.poopImgSize/2, conf.world.h - conf.poopImgSize)
	end
	-- print game stats
	if gameOver then
		currTimeNote = string.format("Your little monster had too much cake. Sorry.\nTime of survival: %.2f seconds.\n", endTime)
		if endTime == player.bestTime then
			bestTimeNote = "This is your current best time!\n"
		else
			bestTimeNote = string.format("This is %.2f below your current best time.\n", player.bestTime - endTime)
		end
		if player.lastTime ~= 0 and player.lastTime ~= endTime then
			if endTime > player.lastTime then
				lastTimeNote = string.format("This is %.2f above your last time.", endTime - player.lastTime)
			else
				lastTimeNote = string.format("This is %.2f below your last time.", player.lastTime - endTime)
			player.lastTime = endTime
			end
		else
			lastTimeNote = ""
			player.lastTime = endTime
		end
		love.graphics.printf({{0, 255, 0, 255}, currTimeNote .. bestTimeNote .. lastTimeNote}, 0, math.floor(conf.world.h/2), conf.world.w, "center")
	end
end

function love.keypressed(key, scancode, isrepeat)
	-- process key input
	if key == "escape" then
		love.event.quit(0)
	end
	if key == "a" and gulpState.exploding < 0 then
		--move left
		gulpState.speed.x = -400
	end
	if key == "d" and gulpState.exploding < 0 then
		-- move right
		gulpState.speed.x = 400
	end
	if key == "s" and gulpState.poopCount > 0 and gulpState.exploding < 0 and gulpState.eating < 0 and gulpState.size < conf.gulpMinSize then
		gulpState.poop = true
	end
	if key == "return" and gameOver then
		restart()
	end
end

function love.keyreleased(key, scancode, isrepeat)
	if key == "a" or key == "d" then
		gulpState.speed.x = 0
	end
end
