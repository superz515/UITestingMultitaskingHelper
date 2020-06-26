# UITestingMultitaskingHelper
Support multitasking (split screen mode) in UITesting.

## Background

In UITesting, we simulate user actions through the APIs provided by XCTest framework. But it doesn’t provide any API to trigger [multitasking](https://support.apple.com/en-us/HT207582#:~:text=To%20turn%20Multitasking%20features%20on,Slide%20Over%20or%20Split%20View.), a.k.a split screen mode.

After tons of searching, while most people say it is impossible to do so, I found a very [old thread](https://developer.apple.com/forums/thread/38973) in Apple developer forum which is asked 4 years ago. The only anwser is added 3 years ago. It's written in OC and doesn't work any more, but I got inspired by it. After a lot of trying and failing, finally I found a way out!

## Idea

The basic idea is to mimic the user actions when we play multitasking with a real device manually. Luckily, there’re only 2 types of actions we need:

Swipe: Obviously, first we need to bring up the dock from bottom edge through a swipe up gesture.

Drag: We need to drag another app to the right side of our app to begin multitasking. Also, we need to drag the grab handle between 2 apps to switch between different split screen modes.

Even better, swipe and drag are actually same kind of action. A swipe begins with a touch on the screen without staying while a drag needs to stay at initial touch point for a while, then they both move to another point. This can be done by a public API ```press(forDuration:thenDragTo:)``` of ```XCUICoordinate``` class provided by XCTest framework. All we need to do is to find 2 ```XCUICoordinate``` (a begin point and an end point of the drag) and a proper duration depending on if it is a swipe or a drag.

## Usage

I use Swift extension to enhance ```XCUIApplication``` with multitasking support. There's only 1 Swift file you need in this repository and it has plenty of comments. Please feel free to add it to your UITesting target and use it.


