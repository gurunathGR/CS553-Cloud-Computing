
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.api.java.function.*;
import scala.Tuple2;
import java.util.*;

public class SparkSort
{
	public static class TokenizerMapper implements FlatMapFunction<String, Tuple2<String, String>>
	{
		public Iterator<Tuple2<String, String>> call(String value) throws Exception
		{
			String[] rows = value.toString().split("\r");
			ArrayList<Tuple2<String, String>> array = new ArrayList<Tuple2<String, String>>(rows.length);
			
			for(int x = 0; x < rows.length; x++) {
				String row = rows[x];
				String ds_key = row.substring(0, 10);
				String ds_value = row + "\r";
				array.add(new Tuple2<String, String>(ds_key, ds_value));
			}
			
			return array.iterator();
		}
	}
	
	public static void main(String[] args)
	{ 
		String input = args[0];
		String output = args[1];
		
		SparkConf sparkConf = new SparkConf().setAppName("SparkSort");
		JavaSparkContext sparkContext = new JavaSparkContext(sparkConf); 
		JavaRDD<String> textFile = sparkContext.textFile(input);
		JavaRDD<String> rows = textFile
			.flatMap(new TokenizerMapper())
			.mapToPair(word -> word) 
			.sortByKey()
			.values();
		rows.saveAsTextFile(output);
	}
}
