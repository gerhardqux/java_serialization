import java.io.FileOutputStream;
import java.io.ObjectOutputStream;
import java.util.Date;

public class ObjectGenerator {

	public static void main(String args[]){
		try {
			FileOutputStream fos = new FileOutputStream("1-integers.obj");
			ObjectOutputStream oos = new ObjectOutputStream(fos);

			oos.writeInt(32);
			oos.writeInt(33);
			oos.writeInt(34);
			oos.close();

			fos = new FileOutputStream("2-string.obj");
			oos = new ObjectOutputStream(fos);
			oos.writeObject("Today");
			oos.close();

			fos = new FileOutputStream("3-date.obj");
			oos = new ObjectOutputStream(fos);
			oos.writeObject(new Date());
			oos.close();

		}
		catch (Exception e) {
			System.out.println(e.getMessage());
		}
	}

}
