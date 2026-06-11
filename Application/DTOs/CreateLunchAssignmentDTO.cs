namespace SRJBackend.Application.DTOs;

public class CreateLunchAssignmentDTO
{
    public int PersonId { get; set; }
    public int? EnrollmentId { get; set; }
    public int LunchId { get; set; }
    public DateOnly AssignedDate { get; set; }
    public bool IsPaid { get; set; }
}
