import java.awt.event.KeyEvent;
import processing.serial.*;
import cc.arduino.*;
import java.util.TimerTask;
import java.util.Timer;
import java.io.FileReader;
import java.io.FileOutputStream;


public class ScriptUnit {
	final int numOfServo = servoPin.length;
	public int []servoAngle;
	public int waitingNumOfFrame;

	public ScriptUnit() {
		servoAngle = new int[numOfServo];
		for(int angle : servoAngle) {
			angle = 0;
		}
		waitingNumOfFrame = 0;
	}

}

public class ServoTask extends TimerTask {
	
	private int []mServoAngle;
	private int numOfServos;
	private Arduino mArduino;

	public ServoTask(int []servoAngle,Arduino arduino) {
		mServoAngle = servoAngle;
		numOfServos = servoAngle.length;
		mArduino = arduino;
	}

	@Override
	public void run() {
		for(int i = 0;i < numOfServos;i++) {
			mArduino.servoWrite(servoPin[i],mServoAngle[i]);
		}
	}

}

Arduino arduino;
final static int []servoPin = new int[]{3,5,9};
int []servoAngle = new int[servoPin.length];
final int inputStrBufferSize = 15;
StringBuffer inputStrBuffer = new StringBuffer(inputStrBufferSize);

String currentScriptName = null;
final String scriptNameExtension = "lampscript";
File currentScriptFile = null;
ArrayList<ScriptUnit> currentScript;

String sketchAbsPath;

void setup() {
	//println("pwd:" + System.getProperty("user.dir"));
	sketchAbsPath = sketchPath("");
	//println("sketch path:" + sketchAbsPath);
	//println(Arduino.list());
	arduino = new Arduino(this,"/dev/tty.usbmodem1421",57600);
	int numOfServo = servoPin.length;
	
	for(int i = 0;i < numOfServo;i++) {
		servoAngle[i] = 0;
		arduino.pinMode(servoPin[i],Arduino.SERVO);
		arduino.servoWrite(servoPin[i],servoAngle[i]);
	}

}

boolean recordScriptFlag = false;
boolean loadScriptFlag = false;
boolean createScriptFlag = false;
boolean emptyScriptFlag = false;

boolean saveScriptFlag = false;
boolean playScriptFlag = false;

void draw() {
	/*
	int c;
	if(recordScriptFlag) { //start to read an number from console and use it as frame number between current frame and next frame
		int bufferIndex = 0;
		try {
			println("start to read number");
			while((c = System.in.read()) > 0) {
				println("get char!");
				if(Character.isDigit(c)) {
					if(bufferIndex < sizeOfinputStrBuffer-1) {
						inputStrBuffer[bufferIndex] = (char) c;
						bufferIndex++;				
					}
				}
				if(c == ESC_Value) {
					recordScriptFlag = false;
					break;
				}
				else if(c == DELETE_Value) {
					if(bufferIndex > 0) {
						bufferIndex--;
					}
				}
				else if(c == ENTER_Value || c == 10) {
					inputStrBuffer[bufferIndex] = 0;
					println(Integer.valueOf(new String(inputStrBuffer)));
					recordScriptFlag = false;
					break;
				}
			}

		}
		catch(Exception e) {
			println(e.getMessage());
		}
		println("end");
	}
	*/
}

final int largeAngle = 10;
final int smallAngle = 1;
final int largestAngle = 180;
final int smallestAngle = 0;

int bufferIndex = 0;
void clean_inputStrBuffer() {
	if(inputStrBuffer.length() != 0) {
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
		println("here1");
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

	printWriter.println(data);
	printWriter.close();

	println("successfully append data:" + data);

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
				if(i < servoPin.length) {
					scriptUnit.servoAngle[i] = Integer.parseInt(parsedData[i]);
				}
				else {
					scriptUnit.waitingNumOfFrame = Integer.parseInt(parsedData[i]);
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
	println("successfully load file name:" + currentScriptName);

	return scriptUnitList;

}

final int [][]servoControlKey = new int[][]{
	{KeyEvent.VK_X,KeyEvent.VK_Z,KeyEvent.VK_V,KeyEvent.VK_C},
	{KeyEvent.VK_UP,KeyEvent.VK_DOWN,KeyEvent.VK_I,KeyEvent.VK_K},
	{KeyEvent.VK_LEFT,KeyEvent.VK_RIGHT,KeyEvent.VK_J,KeyEvent.VK_L}
};

final float numMillisecondsPerFrame = (float)1000/12.0;

void keyPressed() {
	
	if(keyCode == KeyEvent.VK_R) {
		recordScriptFlag = !recordScriptFlag;
		if(recordScriptFlag) {
			println("enter an number as frame value between current and next frame:");
		}
		else {
			println("cancel recording next step");
		}
		clean_inputStrBuffer();
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
		playScriptFlag = !playScriptFlag;
		if(playScriptFlag) {
			if(currentScriptName != null) {
				println("start playing current script name:" + currentScriptName);
			}
			else {
				println("script name is null");
				return;
			}

			if(currentScript != null) {
				int numOfSteps = currentScript.size();
				Timer timer = new Timer();
				for(int i = 0;(i < numOfSteps) && playScriptFlag;i++) {
					ScriptUnit scriptUnit = currentScript.get(i);
					ServoTask task = new ServoTask(scriptUnit.servoAngle, arduino);
					timer.schedule(task, (long)(scriptUnit.waitingNumOfFrame * numMillisecondsPerFrame));
				}
			}
			else {
				println("current script didn't exist,you need to load certain script file");
			}

			playScriptFlag = false;
			println("script player timer setting end");

		}
		else {
			println("stop playing current script");
		}
	}
	else if(keyCode == KeyEvent.VK_F) {
		println("current script name:" + currentScriptName);
	}

	else {
		
		if(recordScriptFlag || createScriptFlag || loadScriptFlag) {
			if(keyCode >= KeyEvent.VK_0 && keyCode <= KeyEvent.VK_9) {
				if(inputStrBuffer.length() < inputStrBufferSize) {
					inputStrBuffer.append(Character.valueOf((char)keyCode).charValue());
				}
				
				if(inputStrBuffer.length() > 0) {
					println("current value:" + Integer.parseInt(inputStrBuffer.toString()));
				}
				else {
					println("empty string");
				}
			}

			if(keyCode == KeyEvent.VK_ENTER) {
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
						tempBuffer.append(inputStrBuffer.toString());
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
			}

			if(keyCode == KeyEvent.VK_BACK_SPACE) {
				int numOfChar = inputStrBuffer.length();
				if(numOfChar > 0) {
					inputStrBuffer.deleteCharAt(numOfChar-1);
				}
				
				if(inputStrBuffer.length() > 0) {
					println("current value:" + Integer.parseInt(inputStrBuffer.toString()));
				}
				else {
					println("empty string");
				}
			}

			
		}
		

		for(int servoIndex = 0;servoIndex < 3;servoIndex++) {
		  if(keyCode == servoControlKey[servoIndex][0]) {

		    servoAngle[servoIndex]+=largeAngle;
		    if(servoAngle[servoIndex] > largestAngle) {
		    	servoAngle[servoIndex] = largestAngle;
		    }
		    arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);
		    
		  }
		  else if(keyCode == servoControlKey[servoIndex][1]){

		  	servoAngle[servoIndex]-=largeAngle;
		  	if(servoAngle[servoIndex] < smallestAngle) {
		    	servoAngle[servoIndex] = smallestAngle;
		    }
		  	arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);

		  }
		  else if(keyCode == servoControlKey[servoIndex][2]) {

		  	servoAngle[servoIndex]+=smallAngle;
		    if(servoAngle[servoIndex] > largestAngle) {
		    	servoAngle[servoIndex] = largestAngle;
		    }
		    arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);

		  }
		  else if(keyCode == servoControlKey[servoIndex][3]) {

		  	servoAngle[servoIndex]-=smallAngle;
		  	if(servoAngle[servoIndex] < smallestAngle) {
		    	servoAngle[servoIndex] = smallestAngle;
		    }
		  	arduino.servoWrite(servoPin[servoIndex],servoAngle[servoIndex]);

		  }

		}
	}

}
