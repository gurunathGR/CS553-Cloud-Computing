import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.NullWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class HadoopSort {

	public static class TokenizerMapper extends Mapper<Object, Text, Text, Text>
	{
		private Text ds_key = new Text();
		private Text ds_value = new Text();

		@Override
		public void map(Object key, Text value, Context context) throws IOException, InterruptedException
		{
			String[] rows = value.toString().split("\r");
			for(int x = 0; x < rows.length; x++) {
				String row = rows[x];
				ds_key.set(row.substring(0, 10));
				ds_value.set(row + "\r");
				context.write(ds_key, ds_value);
			}
		}
	}

	public static class SortReducer extends Reducer<Text,Text,Text,NullWritable>
	{
		@Override
		public void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException
		{
			for (Text val : values) { 
				context.write(val, NullWritable.get());
			}
		}
	}

	public static void main(String[] args) throws Exception
	{
		Configuration conf = new Configuration();
		Job job = Job.getInstance(conf, "HadoopSort");
		job.setJarByClass(HadoopSort.class);
		job.setMapperClass(TokenizerMapper.class);
		job.setMapOutputKeyClass(Text.class);
		job.setMapOutputValueClass(Text.class);
		//job.setCombinerClass(SortReducer.class);
		job.setReducerClass(SortReducer.class);
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(NullWritable.class);
		FileInputFormat.addInputPath(job, new Path(args[0]));
		FileOutputFormat.setOutputPath(job, new Path(args[1]));
		System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
}
