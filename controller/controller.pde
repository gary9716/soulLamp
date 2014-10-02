import java.awt.event.KeyEvent;
import processing.serial.*;
import cc.arduino.*;
import java.util.TimerTask;
import java.util.Timer;
import java.io.FileReader;
import java.io.FileOutputStream;


public class ScriptUnit {
	public int []servoAngle;
	public int numOfFrame;
	public int ledColorIndex;

	public ScriptUnit() {
		servoAngle = new int[numOfServo];
		for(int angle : servoAngle) {
			angle = 0;
		}
		numOfFrame = 0;
		ledColorIndex = 0;
	}

}

/*
public class ServoTask extends TimerTask {
	
	private int []mServoAngle;
	private int numOfServo;
	private Arduino mArduino;

	public ServoTask(int []servoAngle,Arduino arduino) {
		mServoAngle = servoAngle;
		numOfServo = servoAngle.length;
		mArduino = arduino;
	}

	@Override
	public void run() {
		for(int i = 0;i < numOfServo;i++) {
			mArduino.servoWrite(servoPin[i],mServoAngle[i]);
		}
        //println(mServoAngle[0] + " " + mServoAngle[1] + " " + mServoAngle[2]);
	}

}
*/

Arduino arduino = null;

final static int []servoPin = new int[]{3,5,9};
final static int []ledPin = new int[]{6,7,8,10};

final int numOfLed = ledPin.length;
final int numOfServo = servoPin.length;

int []servoAngle = new int[numOfServo];
int []ledValue = new int[numOfLed];

final int inputStrBufferSize = 15;
StringBuffer inputStrBuffer = null;

String currentScriptName = null;
final String scriptNameExtension = "lampscript";
File currentScriptFile = null;
ArrayList<ScriptUnit> currentScript;
final int initialAngle = 90;
final int initialLightness = 255;
int ledColorIndex = 0;

final int analogLargestValue = 255;
final int analogSmallestValue = 0;

// final int led_R_Index = 0;
// final int led_G_Index = 1;
// final int led_B_Index = 2;
// final int led_W_Index = 3;
final int ledLookupTable[][] = new int[][] {
	{analogLargestValue,analogLargestValue,analogLargestValue,Arduino.HIGH}, //dark
	{analogSmallestValue,analogSmallestValue,analogSmallestValue,Arduino.LOW}, //white
	{analogSmallestValue,analogLargestValue,analogLargestValue,Arduino.LOW}, //red
	{analogSmallestValue,200,analogLargestValue,Arduino.LOW}, //orange
	{analogSmallestValue,analogSmallestValue,analogLargestValue,Arduino.LOW}, //yellow
	{analogLargestValue,analogSmallestValue,analogLargestValue,Arduino.LOW}, //green
	{analogLargestValue,analogLargestValue,analogSmallestValue,Arduino.LOW}, //blue 
	{analogSmallestValue,analogLargestValue,analogSmallestValue,Arduino.LOW}, //purple
};
final int numOfLedColorInLookUpTable = ledLookupTable.length;

String sketchAbsPath;
//Timer timer;

void arduinoRelatedPinInit() {
	for(int i = 0;i < numOfServo;i++) {
		servoAngle[i] = initialAngle;
		arduino.pinMode(servoPin[i],Arduino.SERVO);
		arduino.servoWrite(servoPin[i],servoAngle[i]);
	}

	for(int i = 0;i < numOfLed;i++) {
		if(i < numOfLed - 1) {
			ledValue[i] = initialLightness; //dark
			currentScriptLedValue[i] = ledLookupTable[1][i];
			arduino.analogWrite(ledPin[i],ledValue[i]);
		}
		else {
			ledValue[i] = Arduino.HIGH; //dark
			arduino.pinMode(ledPin[i],Arduino.OUTPUT);
			arduino.digitalWrite(ledPin[i],ledValue[i]);
		}
	}
}

void setup() {
	//println("pwd:" + System.getProperty("user.dir"));
	sketchAbsPath = sketchPath("");
	//println("sketch path:" + sketchAbsPath);
	println(Arduino.list());
	//arduino = new Arduino(this,"/dev/tty.usbserial-A602YZLV",57600);
	arduino = new Arduino(this,"/dev/tty.usbmodem1421",57600);
	arduinoRelatedPinInit();
	ledColorIndex = 0;

	inputStrBuffer = new StringBuffer(inputStrBufferSize);
}

boolean recordScriptFlag = false;
boolean loadScriptFlag = false;
boolean createScriptFlag = false;
boolean emptyScriptFlag = false;

boolean saveScriptFlag = false;
boolean playScriptFlag = false;

void draw() {
}

final int largeAngle = 10;
final int smallAngle = 1;
final int largestAngle = 180;
final int smallestAngle = 0;

int bufferIndex = 0;
void clean_inputStrBuffer() {
	if(inputStrBuffer != null && inputStrBuffer.length() != 0) {
		inputStrBuffer = new StringBuffer(inputStrBufferSize);
	}
}

boolean openFile(String fileName,FileMode mode) { //open file from current directory
	try {
		if(fileName != null) {
			currentScriptFile = new File(sketchAbsPath,fileName);
			if( 	currentScriptFile == null
				|| !currentScriptFile.exists() 
				|| !currentScriptFile.isFile() 
				|| (mode == FileMode.read && !currentScriptFile.canRead()) 
				|| ((mode == FileMode.write || mode == FileMode.readAndWrite) && !currentScriptFile.canWrite()) ) {
				println("open file error, not existed or not a normal file or operation is not permitted");
				currentScriptFile = null;
				return false;
			}
		}
		else {
			println("file name is empty");
			return false;
		}
	}
	catch(Exception e) {
		println(e.getMessage());
		return false;
	}

	return true;
}

PrintWriter printWriter = null;

void printlnInFile(String data) {
	if(printWriter == null) {
		if(currentScriptFile == null) {
			if(!openFile(currentScriptName,FileMode.write)) {
				println("write data into file failed");
				return;
			}
		}
		
		try {
			printWriter = new PrintWriter(new FileOutputStream(currentScriptFile, true)); //true for appending
		}
		catch(Exception e) {
			println(e.getMessage());
			return;
		}
	}

	try {
		printWriter.println(data);
		printWriter.close();
		println("successfully append data:" + data);
	}
	catch(Exception e) {
		println(e.getMessage());
	}

	printWriter = null;
	return;
}


BufferedReader bufferedReader = null;

ArrayList<ScriptUnit> readWholeScriptFromFile() {
	if(bufferedReader == null) {
		if(currentScriptFile == null) {
			if(!openFile(currentScriptName,FileMode.read)) {
				println("read whole script file failed");
				return null;
			}
		}

		try{
			bufferedReader = new BufferedReader(new FileReader(currentScriptFile));
		}
		catch(Exception e) {
			println(e.getMessage());
			return null;
		}

	}

	String dataRead;
	ArrayList<ScriptUnit> scriptUnitList = new ArrayList<ScriptUnit>();
	try {
		while((dataRead = bufferedReader.readLine()) != null) {
			String []parsedData = dataRead.split(" ");
			int numOfData = parsedData.length;
			ScriptUnit scriptUnit = new ScriptUnit();
			for(int i = 0;i < numOfData;i++) {
				if(i < numOfServo) {
					scriptUnit.servoAngle[i] = Integer.parseInt(parsedData[i]);
				}
				else if(i == numOfServo){
					scriptUnit.numOfFrame = Integer.parseInt(parsedData[i]);
				}
				else {
					scriptUnit.ledColorIndex = Integer.parseInt(parsedData[i]);
				}
			}
			scriptUnitList.add(scriptUnit);
		}
	}
	catch(Exception e) {
		println(e.getMessage());
		return null;
	}

	try {
		bufferedReader.close();
	}
	catch(Exception e) {
		println(e.getMessage());
	}

	bufferedReader = null;
	if(currentScriptName != null) {
		println("successfully load file name:" + currentScriptName);
	}

	return scriptUnitList;

}

final int [][]servoControlKey = new int[][]{
	{KeyEvent.VK_X,KeyEvent.VK_Z,KeyEvent.VK_V,KeyEvent.VK_C},
	{KeyEvent.VK_UP,KeyEvent.VK_DOWN,KeyEvent.VK_I,KeyEvent.VK_K},
	{KeyEvent.VK_LEFT,KeyEvent.VK_RIGHT,KeyEvent.VK_J,KeyEvent.VK_L}
};

final long numMillisecondsPerFrame = (long)1000.0/20;
int []currentScriptAngle = new int[numOfServo];
int []toAngle = new int[numOfServo];
int []currentScriptLedValue = new int[numOfLed - 1];
int []toLedValue = new int[numOfLed - 1];

void keyPressed() {
	if(keyCode == KeyEvent.VK_Q){
		for(int i = 0;i < numOfServo;i++) {
			servoAngle[i] = initialAngle;
			arduino.servoWrite(servoPin[i],servoAngle[i]);
		}
		for(int i = 0;i < numOfLed - 1;i++) {
			ledValue[i] = initialLightness;
			arduino.analogWrite(ledPin[i],ledValue[i]);
		}
		arduino.digitalWrite(ledPin[numOfLed - 1],Arduino.HIGH);
		return;
    }
	else if(keyCode == KeyEvent.VK_R) {
		recordScriptFlag = !recordScriptFlag;
		if(recordScriptFlag) {
			println("enter an number as frame value between current and next frame:");
		}
		else {
			println("cancel recording next step");
		}
		clean_inputStrBuffer();
		return;
	}
	else if(keyCode == KeyEvent.VK_N) { //new a script file
		createScriptFlag = !createScriptFlag;
		if(createScriptFlag) {
			println("create a new script,please enter script name:");
		}
		else {
			println("cancel creating a new script");
		}
		clean_inputStrBuffer();
		return;
	}
	/*
	else if(keyCode == KeyEvent.VK_E) { //empty script
		if(currentScript != null) {
			currentScript.clear();
		}
		else {
			currentScript = new ArrayList<ScriptUnit>();
		}

		println("clear script");
	}
	*/
	else if(keyCode == KeyEvent.VK_O) { //open
		loadScriptFlag = !loadScriptFlag;
		if(loadScriptFlag) {
			println("load an existed script,please enter the name:");
		}
		else {
			println("cancel loading script");
		}
		clean_inputStrBuffer();
		return;
	}
/*
	else if(keyCode == KeyEvent.VK_S) { //save
		if(currentScriptName) {
			println("save script with current file name:" + currentScriptName);
		}
		else {
			println("script name is null");
			return;
		}


	}
*/
	else if(keyCode == KeyEvent.VK_P) { //play and stop
		
		if(currentScriptName != null) {
			println("start playing current script name:" + currentScriptName);
		}
		else {
			println("script name is null");
			return;
		}

		if(currentScript != null) {
			for(int i = 0;i < numOfServo;i++) {
				currentScriptAngle[i] = initialAngle;
				arduino.servoWrite(servoPin[i],currentScriptAngle[i]);
			}
			int numOfLedIsLighted = 0;
			for(int i = 0;i < numOfLed - 1;i++) {
				if(currentScriptLedValue[i] != analogLargestValue) {
					numOfLedIsLighted++;
				}
				arduino.analogWrite(ledPin[i],currentScriptLedValue[i]);
			}
			if(numOfLedIsLighted > 0) {
				arduino.digitalWrite(ledPin[numOfLed - 1],Arduino.LOW);
			}
			int currentTimeInMillis = millis();
			int numOfSteps = currentScript.size();
			for(int i = 0;i < numOfSteps;i++) {
				ScriptUnit scriptUnit = currentScript.get(i);
				for(int j = 1;j <= scriptUnit.numOfFrame;j++) {
					for(int k = 0;k < numOfServo;k++) {
						toAngle[k] = easingInOutExpo((float)j,
													 (float)currentScriptAngle[k],
													 (float)(scriptUnit.servoAngle[k] - currentScriptAngle[k]),
													 (float)scriptUnit.numOfFrame);
					}
					numOfLedIsLighted = 0;
					for(int k = 0;k < numOfLed - 1;k++) {
						toLedValue[k] = easingInOutExpo((float)j,
												     	(float)currentScriptLedValue[k],
												     	(float)(ledLookupTable[scriptUnit.ledColorIndex][k] - currentScriptLedValue[k]),
												     	(float)scriptUnit.numOfFrame);
						if(toLedValue[k] != analogLargestValue) {
							numOfLedIsLighted++;
						}
					}
					while(millis() - currentTimeInMillis < numMillisecondsPerFrame);
					for(int k = 0;k < numOfServo;k++) {
						print(toAngle[k] + " ");
						arduino.servoWrite(servoPin[k],toAngle[k]);
					}
					println("");

					for(int k = 0;k < numOfLed - 1;k++) {
						arduino.analogWrite(ledPin[k],toLedValue[k]);
					}
					if(numOfLedIsLighted > 0) {
						arduino.digitalWrite(ledPin[numOfLed - 1],Arduino.LOW);
					}
					else {
						arduino.digitalWrite(ledPin[numOfLed - 1],Arduino.HIGH);
					}

					currentTimeInMillis = millis();
				}
				for(int j = 0;j < numOfServo;j++) {
					currentScriptAngle[j] = scriptUnit.servoAngle[j];
				}
				for(int j = 0;j < numOfLed - 1;j++) {
					currentScriptLedValue[j] = ledLookupTable[scriptUnit.ledColorIndex][j];
				}
			}
		}
		else {
			println("current script didn't exist,you need to load certain script file");
		}

		println("script player timer setting end");
		return;
		
	}
	else if(keyCode == KeyEvent.VK_F) {
		println("current script name:" + currentScriptName);
		return;
	}

	else {
		
		if(recordScriptFlag || createScriptFlag || loadScriptFlag) {
			if(keyCode >= KeyEvent.VK_0 && keyCode <= KeyEvent.VK_9) {
				if(inputStrBuffer.length() < inputStrBufferSize) {
					inputStrBuffer.append(Character.valueOf((char)keyCode).charValue());
				}
				
				if(inputStrBuffer.length() > 0) {
					println("current value:" + inputStrBuffer.toString());
				}
				else {
					println("empty string");
				}

				return;
			}

			else if(keyCode == KeyEvent.VK_ENTER) {
				if(inputStrBuffer.length() == 0) {
					println("error:input number is empty");
					return;
				}

				if(createScriptFlag) {
					try {
						currentScriptName = inputStrBuffer.toString() + "." + scriptNameExtension;
						currentScriptFile = new File(sketchAbsPath,currentScriptName);
						if(currentScriptFile == null || !currentScriptFile.createNewFile()) {
							println("failed to create new file:" + currentScriptName + ",maybe file already existed");
						}
						else {
							println("successfully created file name:" + currentScriptName + " at:" + sketchAbsPath);
						}
					}
					catch(Exception e) {
						println(e.getMessage());
					}

				}
				else if(recordScriptFlag) {
					try {
						StringBuffer tempBuffer = new StringBuffer();
						for(int angle : servoAngle) {
							tempBuffer.append(angle + " ");
						}
						tempBuffer.append(inputStrBuffer.toString() + " "); //frameNumber
						tempBuffer.append(ledColorIndex + "");
						printlnInFile(tempBuffer.toString());
					}
					catch(Exception e) {
						println(e.getMessage());
					}
					
				}
				else if(loadScriptFlag) {
					try {
						currentScriptName = inputStrBuffer.toString() + "." + scriptNameExtension;
						if(!openFile(currentScriptName,FileMode.readAndWrite)) {
							println("failed to open file for read and write");
							return;
						}

						currentScript = readWholeScriptFromFile();
					}
					catch(Exception e) {
						println(e.getMessage());
					}

				}

				//turn off all flag
				createScriptFlag = false;
				recordScriptFlag = false;
				loadScriptFlag = false;

				return;
			}

			else if(keyCode == KeyEvent.VK_BACK_SPACE) {
				int numOfChar = inputStrBuffer.length();
				if(numOfChar > 0) {
					inputStrBuffer.deleteCharAt(numOfChar-1);
				}
				
				if(inputStrBuffer.length() > 0) {
					println("current value:" + inputStrBuffer.toString());
				}
				else {
					println("empty string");
				}

				return;
			}

		}
		

		for(int servoIndex = 0;servoIndex < 3;servoIndex++) {
		  if(keyCode == servoControlKey[servoIndex][0]) {

		    servoAngle[servoIndex]+=largeAngle;
		    if(servoAngle[servoIndex] > largestAngle) {
		    	servoAngle[servoIndex] = largestAngle;
		    }
		    arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);
		    return;
		  }
		  else if(keyCode == servoControlKey[servoIndex][1]){

		  	servoAngle[servoIndex]-=largeAngle;
		  	if(servoAngle[servoIndex] < smallestAngle) {
		    	servoAngle[servoIndex] = smallestAngle;
		    }
		  	arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);
		  	return;
		  }
		  else if(keyCode == servoControlKey[servoIndex][2]) {

		  	servoAngle[servoIndex]+=smallAngle;
		    if(servoAngle[servoIndex] > largestAngle) {
		    	servoAngle[servoIndex] = largestAngle;
		    }
		    arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);
		    return;
		  }
		  else if(keyCode == servoControlKey[servoIndex][3]) {

		  	servoAngle[servoIndex]-=smallAngle;
		  	if(servoAngle[servoIndex] < smallestAngle) {
		    	servoAngle[servoIndex] = smallestAngle;
		    }
		  	arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);
		  	return;
		  }

		}

		if(keyCode == KeyEvent.VK_CONTROL) {
			if(ledColorIndex > 0) {
				ledColorIndex--;
				for(int i = 0;i < numOfLed - 1;i++) {
					arduino.analogWrite(ledPin[i],ledLookupTable[ledColorIndex][i]);
				}
				arduino.digitalWrite(ledPin[numOfLed - 1],ledLookupTable[ledColorIndex][numOfLed - 1]);
			}
			return;
		}
		else if(keyCode == KeyEvent.VK_ALT) {
			if(ledColorIndex < numOfLedColorInLookUpTable - 1) {
				ledColorIndex++;
				for(int i = 0;i < numOfLed - 1;i++) {
					arduino.analogWrite(ledPin[i],ledLookupTable[ledColorIndex][i]);
				}
				arduino.digitalWrite(ledPin[numOfLed - 1],ledLookupTable[ledColorIndex][numOfLed - 1]);
			}
			return;
		}

	}

}
private int easingInOutQuad(float t, float b, float c, float d) {
    if ((t/=d/2) < 1) return (int)(c/2*t*t + b);
    return (int)(-c/2 * ((--t)*(t-2) - 1) + b);
}

private int easingInOutExpo(float frameOrder, float start, float delta, float totalFrame) {
    int frameOrderInt = (int)frameOrder;
    int totalFrameInt = (int)totalFrame;
    if (frameOrderInt == 0) return (int)(start);
    if (frameOrderInt == totalFrameInt) return (int)(start + delta);
    if ((frameOrder /= totalFrame/2) < 1) return (int)(delta/2 * (float)Math.pow(2, 10 * (frameOrder - 1)) + start);
    return (int)(delta/2 * (-(float)Math.pow(2, -10 * --frameOrder) + 2) + start);
}
