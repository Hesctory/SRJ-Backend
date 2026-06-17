namespace SRJBackend.Application.DTOs;

public class CreateLunchAssignmentDTO
{
    public int PersonId { get; set; }
    public int? EnrollmentId { get; set; }
    public int ShiftId { get; set; }
    public List<int> LunchIds { get; set; } = [];
    public DateOnly AssignedDate { get; set; }
    public decimal? AmountPaid { get; set; }
}
