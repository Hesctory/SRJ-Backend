using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EnrollmentState
{
    public int Id { get; set; }

    public string? Name { get; set; }

    public virtual ICollection<EnrollmentStateHistory> EnrollmentStateHistoryFromStates { get; set; } = new List<EnrollmentStateHistory>();

    public virtual ICollection<EnrollmentStateHistory> EnrollmentStateHistoryToStates { get; set; } = new List<EnrollmentStateHistory>();

    public virtual ICollection<Enrollment> Enrollments { get; set; } = new List<Enrollment>();
}
