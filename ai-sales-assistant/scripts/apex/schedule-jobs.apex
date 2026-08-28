// Schedules the nightly risk re-scoring / follow-up task job.
// Run with: sf apex run --file scripts/apex/schedule-jobs.apex -o <org alias>
Id jobId = TaskScheduler.scheduleDaily();
System.debug('AI Sales Assistant nightly job scheduled: ' + jobId);
